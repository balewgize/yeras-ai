import 'chat.dart';

/// One persisted conversation (Phase 7): an id, the model it chats with,
/// and the message list. A single SharedPreferences JSON blob holds every
/// conversation; stored text stays small because the model's context
/// window caps how long a conversation can usefully grow.
///
/// [generating] is persisted `true` only while a reply is streaming, so a
/// process death mid-reply is detectable at next launch: it comes back
/// with [generating] cleared and [interrupted] set — the "never silently"
/// half of Phase 6's background story.
class Conversation {
  const Conversation({
    required this.id,
    required this.modelId,
    required this.createdAt,
    required this.updatedAt,
    this.title,
    this.messages = const [],
    this.generating = false,
    this.interrupted = false,
  });

  /// Auto-title length cap (first user message, single line).
  static const int maxTitleLength = 48;

  final String id;

  /// Explicit rename; null means "derive from the first user message".
  final String? title;
  final String modelId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;
  final bool generating;
  final bool interrupted;

  /// Explicit rename, else the first user message, else a fallback.
  String get displayName {
    final explicit = title?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    for (final message in messages) {
      if (message.role == ChatRole.user) {
        final text = message.text.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (text.isEmpty) continue;
        return text.length <= maxTitleLength
            ? text
            : '${text.substring(0, maxTitleLength)}…';
      }
    }
    return 'New chat';
  }

  Conversation copyWith({
    String? title,
    String? modelId,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
    bool? generating,
    bool? interrupted,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      modelId: modelId ?? this.modelId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      generating: generating ?? this.generating,
      interrupted: interrupted ?? this.interrupted,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        if (title != null) 'title': title,
        'modelId': modelId,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'messages': [
          for (final message in messages)
            <String, Object?>{
              'role': message.role.name,
              'text': message.text,
              if (message.tokensPerSecond != null)
                'tokensPerSecond': message.tokensPerSecond,
            },
        ],
        'generating': generating,
        'interrupted': interrupted,
      };

  factory Conversation.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final modelId = json['modelId'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('conversation id');
    }
    if (modelId is! String || modelId.isEmpty) {
      throw const FormatException('conversation modelId');
    }
    if (createdAt is! int || updatedAt is! int) {
      throw const FormatException('conversation timestamps');
    }
    final rawMessages = json['messages'];
    final messages = <ChatMessage>[];
    if (rawMessages is List) {
      for (final entry in rawMessages) {
        if (entry is! Map<String, Object?>) continue;
        final text = entry['text'];
        if (text is! String) continue;
        final rate = entry['tokensPerSecond'];
        messages.add(
          ChatMessage(
            role: entry['role'] == 'assistant'
                ? ChatRole.assistant
                : ChatRole.user,
            text: text,
            tokensPerSecond: rate is num ? rate.toDouble() : null,
          ),
        );
      }
    }
    final title = json['title'];
    return Conversation(
      id: id,
      title: title is String && title.trim().isNotEmpty ? title : null,
      modelId: modelId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
      messages: messages,
      generating: json['generating'] == true,
      interrupted: json['interrupted'] == true,
    );
  }
}
