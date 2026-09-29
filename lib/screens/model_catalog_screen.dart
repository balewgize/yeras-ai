import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/model_catalog.dart';
import '../providers/device_capability_providers.dart';
import '../providers/model_catalog_providers.dart';
import '../utils/format.dart';
import '../widgets/model_download_area.dart';
import '../widgets/section_header.dart';

class ModelCatalogScreen extends ConsumerWidget {
  const ModelCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(labeledCatalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Models'),
        actions: [
          IconButton(
            tooltip: 'Re-check device',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(deviceCapabilitiesProvider);
            },
          ),
        ],
      ),
      body: catalog.when(
        skipLoadingOnReload: true,
        data: (catalog) => _CatalogList(catalog: catalog),
        loading: () => const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (error, _) => _CatalogError(
          message: '$error',
          onRetry: () => ref.invalidate(labeledCatalogProvider),
        ),
      ),
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({required this.catalog});

  final LabeledCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final capabilities = catalog.capabilities;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      itemCount: catalog.entries.length + 1,
      separatorBuilder: (context, index) {
        if (index == 0) return const SizedBox(height: 20);
        return const Divider(height: 1);
      },
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('Catalog'),
              const SizedBox(height: 8),
              Text(
                'Labels are based on this device: '
                '${formatBytes(capabilities.memory.totalBytes)} RAM, '
                '~${formatBytes(capabilities.conservativeModelBudgetBytes)} '
                'usable for models. Speed assumes CPU inference.',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }
        final entry = catalog.entries[index - 1];
        return _ModelCard(entry: entry);
      },
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.entry});

  final LabeledCatalogModel entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final model = entry.model;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  model.name,
                  style: textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _FitBadge(fit: entry.fit),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${formatBytes(model.sizeBytes)} · '
            '${model.contextLength ~/ 1024}K context',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            model.description,
            style: textTheme.bodySmall?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 12),
          ModelDownloadArea(model: model),
        ],
      ),
    );
  }
}

class _FitBadge extends StatelessWidget {
  const _FitBadge({required this.fit});

  final ModelFit fit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (label, background, foreground) = switch (fit) {
      ModelFit.recommended => (
          'Recommended',
          scheme.primary,
          scheme.onPrimary,
        ),
      ModelFit.willBeSlow => (
          'Will be slow',
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
      ModelFit.wontFit => (
          "Won't fit",
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: textTheme.bodySmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load the model catalog', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
