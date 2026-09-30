import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/chat_providers.dart';
import '../../utils/format.dart';

/// Top-bar action: the single intentional entry point for loading the
/// active model into memory and unloading it again.
class ModelLoadButton extends ConsumerWidget {
  const ModelLoadButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeModelProvider);
    final chat = ref.watch(chatControllerProvider);
    final isLoaded = ref.watch(isModelLoadedProvider);
    final scheme = Theme.of(context).colorScheme;

    if (chat.stage == ChatStage.loadingModel) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final busy = chat.isBusy;
    final loaded = isLoaded && active != null;
    return IconButton(
      tooltip: active == null
          ? 'No model downloaded'
          : loaded
          ? 'Unload ${active.name} - free memory'
          : 'Load ${active.name} into memory',
      onPressed: active == null || busy
          ? null
          : () {
              HapticFeedback.lightImpact();
              final notifier = ref.read(chatControllerProvider.notifier);
              if (loaded) {
                notifier.unloadModel();
              } else {
                notifier.loadActiveModel();
              }
            },
      icon: Icon(
        loaded ? Icons.power_settings_new : Icons.power_settings_new_outlined,
        color: loaded ? scheme.primary : null,
      ),
    );
  }
}

/// AppBar title: the active model name (or StayLocal when nothing is
/// downloaded). Tapping opens the model picker sheet — the same spot
/// ChatGPT/Gemini put their model switcher.
class ModelPickerTitle extends ConsumerWidget {
  const ModelPickerTitle({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeModelProvider);
    final isLoaded = ref.watch(isModelLoadedProvider);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.circle,
                  size: 8,
                  color: isLoaded ? Colors.green : scheme.outline,
                ),
              ),
            Flexible(
              child: Text(
                active?.name ?? 'StayLocal',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class ModelPickerSheet extends ConsumerWidget {
  const ModelPickerSheet({super.key, required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloaded = ref.watch(downloadedModelsProvider);
    final selectedId = ref.watch(selectedModelIdProvider);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Models',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (downloaded.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'No models downloaded yet. Models run fully offline '
                  'on your device.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                      for (final model in downloaded)
                        ListTile(
                          title: Text(model.name),
                          subtitle: Text(
                            '${formatBytes(model.sizeBytes)} · '
                            '${model.contextLength ~/ 1024}K context',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        trailing:
                            selectedId == model.id ||
                                (selectedId == null &&
                                    model == downloaded.first)
                            ? Icon(Icons.check, color: scheme.primary)
                            : null,
                        onTap: () {
                          ref
                              .read(selectedModelIdProvider.notifier)
                              .select(model.id);
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: FilledButton.tonalIcon(
                onPressed: onBrowse,
                label: const Text('View all models'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
