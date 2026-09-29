import 'package:staylocal/data/repositories/chat_history_repository.dart';
import 'package:staylocal/models/conversation.dart';

/// In-memory chat history fake mirroring the real repository's
/// newest-first order and interruption normalization.
class FakeChatHistoryRepository implements ChatHistoryRepository {
  final Map<String, Conversation> _conversations = <String, Conversation>{};

  /// Seed stored conversations directly (tests control stored flags).
  void seed(Iterable<Conversation> conversations) {
    for (final conversation in conversations) {
      _conversations[conversation.id] = conversation;
    }
  }

  Conversation? stored(String id) => _conversations[id];

  List<Conversation> get all => _conversations.values.toList();

  @override
  Future<List<Conversation>> loadConversations() async {
    for (final entry in _conversations.entries.toList()) {
      if (entry.value.generating) {
        _conversations[entry.key] =
            entry.value.copyWith(generating: false, interrupted: true);
      }
    }
    final list = _conversations.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<void> saveConversation(Conversation conversation) async {
    _conversations[conversation.id] = conversation;
  }

  @override
  Future<void> deleteConversation(String id) async {
    _conversations.remove(id);
  }
}
