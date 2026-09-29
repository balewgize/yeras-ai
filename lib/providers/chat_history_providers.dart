import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/chat_history_repository.dart';
import '../models/conversation.dart';

final chatHistoryRepositoryProvider = Provider<ChatHistoryRepository>(
  (ref) => SharedPreferencesChatHistoryRepository(),
);

/// Newest-first conversation list for the drawer. Storage loading is
/// async; the list starts empty and fills in a moment later.
class ConversationsController extends Notifier<List<Conversation>> {
  @override
  List<Conversation> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    state = await ref.read(chatHistoryRepositoryProvider).loadConversations();
  }

  /// Insert or replace by id and keep newest-first order.
  Future<void> upsert(Conversation conversation) async {
    await ref
        .read(chatHistoryRepositoryProvider)
        .saveConversation(conversation);
    final updated = [
      for (final existing in state)
        if (existing.id != conversation.id) existing,
      conversation,
    ];
    updated.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = updated;
  }

  /// Rename by id; a no-op when the conversation is already gone.
  Future<void> renameConversation(String id, String title) async {
    Conversation? target;
    for (final existing in state) {
      if (existing.id == id) target = existing;
    }
    if (target == null) return;
    await upsert(
      target.copyWith(title: title.trim(), updatedAt: DateTime.now()),
    );
  }

  Future<void> deleteConversation(String id) async {
    await ref.read(chatHistoryRepositoryProvider).deleteConversation(id);
    state = [for (final existing in state) if (existing.id != id) existing];
  }
}

final conversationsProvider =
    NotifierProvider<ConversationsController, List<Conversation>>(
  ConversationsController.new,
);
