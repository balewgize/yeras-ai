import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/chat_providers.dart';
import '../../utils/format.dart';

/// Inline status line above the composer: loading progress, load/unload
/// results, errors, or the explicit Load action. Text + button — the top-bar
/// power icon mirrors the same action.
class StatusArea extends ConsumerWidget {
  const StatusArea({
    super.key,
    required this.onRetry,
    required this.onBrowse,
    required this.onNewChat,
    required this.onLoad,
  });

  final VoidCallback onRetry;
  final VoidCallback onBrowse;
  final VoidCallback onNewChat;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatControllerProvider);
    final active = ref.watch(activeModelProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget row({
      required String text,
      required Color color,
    }) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                text,
                style: textTheme.bodySmall?.copyWith(color: color),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    if (chat.stage == ChatStage.loadingModel) {
      return row(
        text: 'Loading ${chat.loadingModelName ?? 'model'}…',
        color: scheme.onSurfaceVariant,
      );
    }

    final error = chat.errorMessage;
    if (error != null) {
      final hasModel = active != null;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                error,
                style: textTheme.bodySmall?.copyWith(color: scheme.error),
                textAlign: TextAlign.center,
              ),
            ),
            // Keep legacy escape hatches discoverable alongside the
            // intentional top-bar load flow.
            if (chat.contextFull)
              TextButton(
                onPressed: onNewChat,
                child: const Text('New chat'),
              )
            else if (!hasModel)
              TextButton(
                onPressed: onBrowse,
                child: const Text('Browse models'),
              )
            else if (chat.messages.isNotEmpty)
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
          ],
        ),
      );
    }

    final info = chat.infoMessage;
    if (info != null) {
      final isUnload = info.contains('unloaded');
      return row(
        text: info,
        color: isUnload ? scheme.onSurfaceVariant : scheme.primary,
      );
    }

    if (active != null) {
      final isLoaded = chat.loadedModelId == active.id;
      if (!isLoaded) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
          child: FilledButton.tonal(
            onPressed: chat.isBusy ? null : onLoad,
            child: Text(
              'Load ${active.name} · ${formatBytes(active.sizeBytes)}',
            ),
          ),
        );
      }
    } else {
      return row(
        text: 'Download a model first, then ask away.',
        color: scheme.onSurfaceVariant,
      );
    }

    return const SizedBox.shrink();
  }
}
