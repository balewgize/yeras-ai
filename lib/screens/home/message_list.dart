import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../models/chat.dart';

class MessageList extends StatelessWidget {
  const MessageList({
    super.key,
    required this.scrollController,
    required this.messages,
    required this.streaming,
    this.showInterrupted = false,
  });

  final ScrollController scrollController;
  final List<ChatMessage> messages;
  final bool streaming;

  /// True when the conversation was restored from an interrupted reply:
  /// the trailing assistant bubble gets an in-place Interrupted caption.
  final bool showInterrupted;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isLast = index == messages.length - 1;
        return switch (message.role) {
          ChatRole.user => UserBubble(text: message.text),
          ChatRole.assistant => AssistantBubble(
              text: message.text,
              live: streaming && isLast,
              tokensPerSecond: message.tokensPerSecond,
              showRate: !streaming || !isLast,
              interrupted: showInterrupted &&
                  isLast &&
                  message.role == ChatRole.assistant &&
                  !streaming,
            ),
        };
      },
    );
  }
}

class UserBubble extends StatelessWidget {
  const UserBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: SelectableText(
          text,
          style: TextStyle(color: scheme.onSurface),
        ),
      ),
    );
  }
}

class AssistantBubble extends StatelessWidget {
  const AssistantBubble({
    super.key,
    required this.text,
    required this.live,
    required this.tokensPerSecond,
    required this.showRate,
    this.interrupted = false,
  });

  final String text;
  final bool live;
  final double? tokensPerSecond;
  final bool showRate;
  final bool interrupted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final rate = tokensPerSecond;

    // Plain full-bleed markdown like ChatGPT/Claude — no bubble, no bg.
    // Render markdown live too so **bold** etc. formats during streaming;
    // partial constructs settle as tokens arrive. The ▍ cursor marks live.
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (text.isEmpty)
              SelectableText(
                '…',
                style: textTheme.bodyLarge?.copyWith(height: 1.5),
              )
            else
              MarkdownBody(
                data: live ? '$text▍' : text,
                selectable: true,
                styleSheet: _assistantSheet(context),
              ),
            if (showRate && rate != null) ...[
              const SizedBox(height: 4),
              Text(
                '${rate.toStringAsFixed(1)} tok/s · on-device',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (interrupted) ...[
              const SizedBox(height: 4),
              Text(
                'Interrupted',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Markdown styling for finished assistant turns: body-like text with
/// theme-aware code blocks, quotes, and tables.
MarkdownStyleSheet _assistantSheet(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final textTheme = theme.textTheme;
  final body = textTheme.bodyLarge?.copyWith(height: 1.5);
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: body,
    h1: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    h2: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    h3: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    code: textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      backgroundColor: scheme.surfaceContainerHighest,
      height: 1.4,
    ),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: BoxDecoration(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: scheme.primary, width: 3)),
    ),
  );
}
