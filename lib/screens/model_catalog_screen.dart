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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        const SectionHeader('Catalog'),
        const SizedBox(height: 8),
        Text(
          'Labels are based on this device: '
          '${formatBytes(capabilities.memory.totalBytes)} RAM, '
          '~${formatBytes(capabilities.conservativeModelBudgetBytes)} '
          'usable for models. Speed assumes CPU inference.',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        for (final entry in catalog.entries) _ModelCard(entry: entry),
      ],
    );
  }
}

class _ModelCard extends StatefulWidget {
  const _ModelCard({required this.entry});

  final LabeledCatalogModel entry;

  @override
  State<_ModelCard> createState() => _ModelCardState();
}

class _ModelCardState extends State<_ModelCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entry = widget.entry;
    final model = entry.model;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
              child: Row(
                children: [
                  _ModelGlyph(fit: entry.fit),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.name,
                          style: textTheme.titleSmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${model.parameterCountLabel} · '
                          '${model.quantization} · '
                          '${formatBytes(model.sizeBytes)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _FitIndicator(fit: entry.fit),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: Icon(
                      Icons.expand_more,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: ModelDownloadArea(model: model),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _ModelDetails(entry: entry)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ModelDetails extends StatelessWidget {
  const _ModelDetails({required this.entry});

  final LabeledCatalogModel entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final model = entry.model;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            model.description,
            style: textTheme.bodySmall?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Parameters',
            value:
                '${model.parameterCountLabel} '
                '(${model.parameterCountInBillions.toStringAsFixed(1)}B)',
          ),
          _DetailRow(label: 'Quantization', value: model.quantization),
          _DetailRow(
            label: 'Context',
            value: '${model.contextLength ~/ 1024}K tokens',
          ),
          _DetailRow(label: 'File size', value: formatBytes(model.sizeBytes)),
          _DetailRow(label: 'Min RAM', value: '${model.minRamGb} GB'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                switch (entry.fit) {
                  ModelFit.recommended => Icons.check_circle_outline,
                  ModelFit.willBeSlow => Icons.speed_outlined,
                  ModelFit.wontFit => Icons.warning_amber_outlined,
                },
                size: 16,
                color: _fitColor(scheme, entry.fit),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _fitExplanation(entry.fit),
                  style: textTheme.bodySmall?.copyWith(
                    color: _fitColor(scheme, entry.fit),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelGlyph extends StatelessWidget {
  const _ModelGlyph({required this.fit});

  final ModelFit fit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.memory, size: 20, color: _fitColor(scheme, fit)),
    );
  }
}

class _FitIndicator extends StatelessWidget {
  const _FitIndicator({required this.fit});

  final ModelFit fit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = _fitColor(scheme, fit);
    final label = switch (fit) {
      ModelFit.recommended => 'Recommended',
      ModelFit.willBeSlow => 'Will be slow',
      ModelFit.wontFit => "Won't fit",
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

Color _fitColor(ColorScheme scheme, ModelFit fit) => switch (fit) {
  ModelFit.recommended => scheme.primary,
  ModelFit.willBeSlow => scheme.tertiary,
  ModelFit.wontFit => scheme.error,
};

String _fitExplanation(ModelFit fit) => switch (fit) {
  ModelFit.recommended => 'Runs comfortably on this device.',
  ModelFit.willBeSlow =>
    'Runs on this device, but responses will be noticeably slower.',
  ModelFit.wontFit =>
    'Needs more memory than this device can safely spare. Loading it may crash the app.',
};

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
            Text(
              'Could not load the model catalog',
              style: textTheme.titleMedium,
            ),
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
