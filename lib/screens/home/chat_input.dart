import 'package:flutter/material.dart';

class ChatInput extends StatelessWidget {
  const ChatInput({
    super.key,
    required this.controller,
    required this.hasText,
    required this.busy,
    required this.generating,
    required this.isLoaded,
    required this.activeModelName,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool hasText;
  final bool busy;
  final bool generating;
  final bool isLoaded;
  final String? activeModelName;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canSend = hasText && !busy && isLoaded;
    final name = activeModelName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: isLoaded
                          ? 'Message'
                          : name == null
                              ? 'Message'
                              : 'Load $name to start',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                if (generating)
                  IconButton.filled(
                    tooltip: 'Stop',
                    onPressed: onStop,
                    icon: const Icon(Icons.stop),
                  )
                else
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: canSend ? () => onSend() : null,
                    icon: const Icon(Icons.arrow_upward),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
