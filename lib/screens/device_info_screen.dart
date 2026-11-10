import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_capabilities.dart';
import '../providers/device_capability_providers.dart';
import '../utils/format.dart';

class DeviceInfoScreen extends ConsumerWidget {
  const DeviceInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(deviceCapabilitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your device'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(deviceCapabilitiesProvider),
          ),
        ],
      ),
      body: capabilities.when(
        skipLoadingOnReload: true,
        data: (capabilities) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [_DeviceCard(capabilities: capabilities)],
        ),
        loading: () => const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, _) => _DetectionError(
          onRetry: () => ref.invalidate(deviceCapabilitiesProvider),
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.capabilities});

  final DeviceCapabilities capabilities;

  bool get _gpuSupported => capabilities.accelerators.any(
        (accelerator) => accelerator.type == AcceleratorType.gpu,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final identity = capabilities.identity;
    final memory = capabilities.memory;
    final storage = capabilities.storage;
    final inUseBytes = memory.totalBytes - memory.availableBytes;
    final inUseFraction =
        memory.totalBytes > 0 ? inUseBytes / memory.totalBytes : 0.0;
    final inUsePercent = (inUseFraction * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your device',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          _DeviceRow(
            icon: Icons.smartphone,
            label: 'Model',
            value: '${identity.manufacturer} ${identity.model}',
          ),
          _DeviceRow(
            icon: Icons.android,
            label: 'Android',
            value: identity.osVersion,
          ),
          _DeviceRow(
            icon: Icons.memory,
            label: 'RAM',
            value: formatBytes(memory.totalBytes),
            subLines: [
              'Free ≈ ${formatBytes(memory.availableBytes)}',
              'In use ≈ $inUsePercent% · ${formatBytes(inUseBytes)}',
            ],
            trailing: SizedBox(
              width: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: inUseFraction.clamp(0.0, 1.0),
                  minHeight: 5,
                  color: scheme.onSurface,
                  backgroundColor: scheme.outlineVariant,
                ),
              ),
            ),
          ),
          _DeviceRow(
            icon: Icons.tune,
            label: 'CPU',
            value:
                '${capabilities.cpuCores} cores · ${capabilities.cpuTierLabel}',
          ),
          _DeviceRow(
            icon: Icons.sd_storage,
            label: 'Storage',
            value: '${formatBytes(storage.freeBytes)} / '
                '${formatBytes(storage.totalBytes)}',
          ),
          _DeviceRow(
            icon: Icons.speed,
            label: 'GPU',
            value: _gpuSupported ? 'Supported' : 'Not supported',
          ),
          _DeviceRow(
            icon: Icons.speed,
            label: 'Performance',
            value: capabilities.performanceClassLabel,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              capabilities.performanceClassNote,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.icon,
    required this.label,
    required this.value,
    this.subLines = const [],
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final List<String> subLines;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final valueStyle = textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
              Icon(icon, size: 24, color: scheme.onSurface),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: valueStyle,
                    ),
                    for (final line in subLines)
                      Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (trailing != null) ...[
                      const SizedBox(height: 6),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
  }
}

class _DetectionError extends StatelessWidget {
  const _DetectionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't check your device",
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
