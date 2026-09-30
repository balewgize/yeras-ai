import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/model_catalog.dart';
import '../models/model_download.dart';
import '../providers/model_download_providers.dart';
import '../utils/format.dart';

class ModelDownloadArea extends ConsumerWidget {
  const ModelDownloadArea({super.key, required this.model});

  final CatalogModel model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(modelDownloadStateProvider(model.id));

    return state.when(
      skipLoadingOnReload: true,
      data: (state) => _DownloadAreaContent(model: model, state: state),
      loading: () => const SizedBox.shrink(),
      error: (error, _) => _DownloadAreaContent(
        model: model,
        state: ModelDownloadState(
          stage: DownloadStage.stopped,
          errorMessage: 'Download state error: $error',
        ),
      ),
    );
  }
}

class _DownloadAreaContent extends ConsumerWidget {
  const _DownloadAreaContent({required this.model, required this.state});

  final CatalogModel model;
  final ModelDownloadState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(modelDownloadRepositoryProvider);

    if (state.stage == DownloadStage.notDownloaded &&
        state.partialBytes == 0) {
      return Row(
        children: [
          const Spacer(),
          FilledButton.icon(
            onPressed: () => repository.start(model.id),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download'),
          ),
        ],
      );
    }
    if (state.stage == DownloadStage.notDownloaded ||
        state.stage == DownloadStage.stopped) {
      return _ResumableArea(
        model: model,
        state: state,
        onResume: () => repository.start(model.id),
        onDelete: () => repository.delete(model.id),
      );
    }
    if (state.stage == DownloadStage.ready) {
      return _ReadyRow(
        model: model,
        state: state,
        onDelete: () => repository.delete(model.id),
      );
    }
    return switch (state.stage) {
      DownloadStage.preparing => _ProgressArea(
        label: 'Preparing…',
        fraction: null,
        onCancel: () => repository.cancel(model.id),
      ),
      DownloadStage.downloading => _ProgressArea(
        label: _byteLabel(state, fallbackTotal: model.sizeBytes),
        fraction: state.fraction,
        onCancel: () => repository.cancel(model.id),
        keepOpenHint: true,
      ),
      DownloadStage.verifying => const _ProgressArea(
        label: 'Finishing…',
        fraction: null,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  String _byteLabel(ModelDownloadState state, {required int fallbackTotal}) {
    final total = state.totalBytes ?? fallbackTotal;
    final counter = (total <= 0)
        ? (state.receivedBytes > 0
              ? 'Downloading… ${formatBytes(state.receivedBytes)}'
              : 'Downloading…')
        : '${formatBytes(state.receivedBytes)} of ${formatBytes(total)}';
    final speed = state.speedBytesPerSecond;
    return speed == null ? counter : '$counter · ${formatSpeed(speed)}';
  }
}

class _ResumableArea extends StatelessWidget {
  const _ResumableArea({
    required this.model,
    required this.state,
    required this.onResume,
    required this.onDelete,
  });

  final CatalogModel model;
  final ModelDownloadState state;
  final VoidCallback onResume;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final done = state.partialBytes > 0
        ? state.partialBytes
        : state.receivedBytes;
    final total = state.totalBytes ?? model.sizeBytes;
    final hasProgress = done > 0 && total > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.errorMessage != null) ...[
          Text(
            state.errorMessage!,
            style: textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                hasProgress
                    ? '${formatBytes(done)} of ${formatBytes(total)}'
                    : 'Not started',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (hasProgress)
              IconButton(
                tooltip: 'Delete partial download',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, partial: true),
              ),
            FilledButton.tonalIcon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume'),
            ),
          ],
        ),
        if (hasProgress) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (done / total).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context, {
    required bool partial,
  }) async {
    final done = state.partialBytes > 0
        ? state.partialBytes
        : state.receivedBytes;
    final confirmed = await showDeleteModelDialog(
      context,
      modelName: model.name,
      partial: partial,
      partialBytes: done,
    );
    if (confirmed) await onDelete();
  }
}

class _ProgressArea extends StatelessWidget {
  const _ProgressArea({
    required this.label,
    required this.fraction,
    this.onCancel,
    this.keepOpenHint = false,
  });

  final String label;
  final double? fraction;
  final VoidCallback? onCancel;
  final bool keepOpenHint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (onCancel != null)
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        if (keepOpenHint) ...[
          const SizedBox(height: 6),
          Text(
            'Keep the app open to finish.',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReadyRow extends StatelessWidget {
  const _ReadyRow({
    required this.model,
    required this.state,
    required this.onDelete,
  });

  final CatalogModel model;
  final ModelDownloadState state;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(Icons.check_circle_outline, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            state.receivedBytes > 0
                ? 'Downloaded · ${formatBytes(state.receivedBytes)}'
                : 'Downloaded',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Delete model',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final confirmed = await showDeleteModelDialog(
              context,
              modelName: model.name,
              partial: false,
            );
            if (confirmed) await onDelete();
          },
        ),
      ],
    );
  }
}

/// Shared destructive confirmation for removing a downloaded or partially
/// downloaded model. Returns true only when the user confirms.
Future<bool> showDeleteModelDialog(
  BuildContext context, {
  required String modelName,
  required bool partial,
  int partialBytes = 0,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        partial ? 'Discard partial download?' : 'Delete $modelName?',
      ),
      content: Text(
        partial
            ? 'The ${partialBytes > 0 ? formatBytes(partialBytes) : 'partially downloaded data'} '
                  'will be removed from this device. You will need to start '
                  'over next time.'
            : 'The downloaded model file will be removed from this device. '
                  'You can download it again later.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          onPressed: () => Navigator.pop(context, true),
          child: Text(partial ? 'Discard' : 'Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
