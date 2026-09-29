import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/conversation.dart';

abstract class ChatHistoryRepository {
  /// All conversations, newest first. A conversation caught mid-generation
  /// (the process died while streaming) comes back with
  /// [Conversation.generating] cleared and [Conversation.interrupted] set
  /// — never silently.
  Future<List<Conversation>> loadConversations();

  Future<void> saveConversation(Conversation conversation);

  /// Idempotent: deleting an already-gone conversation is a no-op.
  Future<void> deleteConversation(String id);
}

class SharedPreferencesChatHistoryRepository
    implements ChatHistoryRepository {
  static const String storageKey = 'chat_conversations';

  /// Serializes writes so overlapping saves during streaming can't
  /// interleave their read-modify-write cycles.
  Future<void> _lastWrite = Future<void>.value();

  Future<void> _serialized(Future<void> Function() action) {
    final run = _lastWrite.then((_) => action());
    _lastWrite = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  @override
  Future<List<Conversation>> loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decode(prefs.getString(storageKey));
    final normalized = <Conversation>[];
    var needsRewrite = false;
    for (final conversation in list) {
      // A generation that never finished means the process died mid-reply.
      // Surface that honestly at next launch instead of a silent stump.
      if (conversation.generating) {
        needsRewrite = true;
        normalized.add(
          conversation.copyWith(generating: false, interrupted: true),
        );
      } else {
        normalized.add(conversation);
      }
    }
    normalized.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (needsRewrite) {
      await prefs.setString(storageKey, _encode(normalized));
    }
    return normalized;
  }

  @override
  Future<void> saveConversation(Conversation conversation) {
    return _serialized(() async {
      final prefs = await SharedPreferences.getInstance();
      final list = _decode(prefs.getString(storageKey));
      final updated = <Conversation>[];
      var found = false;
      for (final existing in list) {
        if (existing.id == conversation.id) {
          updated.add(conversation);
          found = true;
        } else {
          updated.add(existing);
        }
      }
      if (!found) updated.add(conversation);
      updated.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      await prefs.setString(storageKey, _encode(updated));
    });
  }

  @override
  Future<void> deleteConversation(String id) {
    return _serialized(() async {
      final prefs = await SharedPreferences.getInstance();
      final list = _decode(prefs.getString(storageKey));
      final remaining = [
        for (final existing in list)
          if (existing.id != id) existing,
      ];
      if (remaining.length == list.length) return;
      await prefs.setString(storageKey, _encode(remaining));
    });
  }

  String _encode(List<Conversation> conversations) {
    return jsonEncode([for (final c in conversations) c.toJson()]);
  }

  /// Corrupt storage never crashes the app: a bad blob yields an empty
  /// list, a bad entry is dropped while the rest survives.
  List<Conversation> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final conversations = <Conversation>[];
      for (final entry in decoded) {
        if (entry is! Map<String, Object?>) continue;
        try {
          conversations.add(Conversation.fromJson(entry));
        } catch (_) {
          continue;
        }
      }
      return conversations;
    } on FormatException {
      return const [];
    }
  }
}
