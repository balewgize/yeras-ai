import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_capabilities.dart';
import '../providers/device_capability_providers.dart';
import '../utils/format.dart';
import '../widgets/section_header.dart';

class DeviceInfoScreen extends ConsumerWidget {
  const DeviceInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(deviceCapabilitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device'),
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
        data: (capabilities) => _DeviceDetails(capabilities: capabilities),
        loading: () => const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (error, _) => _DetectionError(
          message: '$error',
          onRetry: () => ref.invalidate(deviceCapabilitiesProvider),
        ),
      ),
    );
  }
}

class _DeviceDetails extends StatelessWidget {
  const _DeviceDetails({required this.capabilities});

  final DeviceCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final identity = capabilities.identity;
    final memory = capabilities.memory;
    final storage = capabilities.storage;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        const SectionHeader('This device'),
        const SizedBox(height: 8),
        _Row(label: 'Manufacturer', value: identity.manufacturer),
        _Row(label: 'Model', value: identity.model),
        _Row(label: 'Chipset', value: identity.chipsetVendor ?? identity.hardware),
        _Row(label: 'Board', value: identity.board),
        _Row(label: 'OS', value: identity.osVersion),
        const SizedBox(height: 32),
        const SectionHeader('Memory'),
        const SizedBox(height: 8),
        _Row(label: 'Total RAM', value: formatBytes(memory.totalBytes)),
        _Row(label: 'Available RAM', value: formatBytes(memory.availableBytes)),
        _Row(
          label: 'Recommended max model size',
          value: '≤ ${formatBytes(capabilities.conservativeModelBudgetBytes)}',
        ),
        const SizedBox(height: 32),
        const SectionHeader('Storage'),
        const SizedBox(height: 8),
        _Row(label: 'Free (app storage)', value: formatBytes(storage.freeBytes)),
        _Row(label: 'Total capacity', value: formatBytes(storage.totalBytes)),
        const SizedBox(height: 32),
        const SectionHeader('Accelerators'),
        const SizedBox(height: 8),
        for (final accelerator in capabilities.accelerators) ...[
          _AcceleratorTile(accelerator: accelerator),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _AcceleratorTile extends StatelessWidget {
  const _AcceleratorTile({required this.accelerator});

  final AcceleratorInfo accelerator;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statusLabel = switch (accelerator.status) {
      AcceleratorStatus.usedByEngine => 'Used for inference',
      AcceleratorStatus.pendingVerification =>
        'Detected · verification with the engine pending',
      AcceleratorStatus.notUsed => 'Not used for inference',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          accelerator.name,
          style: textTheme.titleSmall?.copyWith(color: scheme.onSurface),
        ),
        if (accelerator.detail != null) ...[
          const SizedBox(height: 2),
          Text(
            accelerator.detail!,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 2),
        Text(
          statusLabel,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DetectionError extends StatelessWidget {
  const _DetectionError({required this.message, required this.onRetry});

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
            Text('Could not detect device capabilities', style: textTheme.titleMedium),
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
