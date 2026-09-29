enum ChatRole { user, assistant }

/// One message in the on-device conversation (Phase 5: in-memory only,
/// persistence lands in Phase 7).
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.tokensPerSecond,
  });

  final ChatRole role;
  final String text;
  final double? tokensPerSecond;

  ChatMessage appending(String token) => ChatMessage(
        role: role,
        text: '$text$token',
      );

  ChatMessage withRate(double? rate) => ChatMessage(
        role: role,
        text: text,
        tokensPerSecond: rate,
      );
}
