import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_capabilities.dart';
import '../providers/device_capability_providers.dart';
import '../providers/generation_settings_providers.dart';
import '../providers/theme_controller.dart';
import '../utils/format.dart';
import '../widgets/section_header.dart';
import 'device_info_screen.dart';
import 'model_catalog_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final settings = ref.watch(generationSettingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          const SectionHeader('Appearance'),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {themeMode},
            onSelectionChanged: (selection) {
              ref
                  .read(themeControllerProvider.notifier)
                  .setThemeMode(selection.first);
            },
          ),
          const SizedBox(height: 32),
          _SettingsTile(
            title: 'Models',
            subtitle: 'See what fits your phone',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ModelCatalogScreen(),
              ),
            ),
          ),
          _SettingsTile(
            title: 'Your device',
            subtitle: ref.watch(deviceCapabilitiesProvider).when(
                  data: _deviceSummary,
                  loading: () => 'Checking…',
                  error: (_, _) => 'Could not check',
                  skipLoadingOnReload: true,
                  skipLoadingOnRefresh: true,
                  skipError: true,
                ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DeviceInfoScreen(),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const SectionHeader('Advanced'),
          const SizedBox(height: 4),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            shape: const Border(),
            collapsedShape: const Border(),
            title: const Text('AI behavior'),
            subtitle: Text(
              settings.isDefault ? 'Default' : 'Custom',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Creativity',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    _creativityLabel(settings.temperature),
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Slider(
                value: settings.temperature,
                min: GenerationSettings.minTemperature,
                max: GenerationSettings.maxTemperature,
                divisions: 15,
                label: _creativityLabel(settings.temperature),
                onChanged: (value) {
                  ref
                      .read(generationSettingsProvider.notifier)
                      .setTemperature(value);
                },
              ),
              Text(
                'Focused gives direct answers, creative gives surprising ones. '
                'Applies to the next reply.',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Memory',
                  style: textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1024, label: Text('Short')),
                  ButtonSegment(value: 2048, label: Text('Standard')),
                  ButtonSegment(value: 4096, label: Text('Long')),
                ],
                selected: {settings.contextSize},
                onSelectionChanged: (selection) {
                  ref
                      .read(generationSettingsProvider.notifier)
                      .setContextSize(selection.first);
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Longer remembers more of the conversation but uses more '
                'memory. Applies the next time a model loads.',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: settings.isDefault
                      ? null
                      : () {
                          ref
                              .read(generationSettingsProvider.notifier)
                              .resetDefaults();
                        },
                  child: const Text('Reset to defaults'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'YerasAI runs AI models entirely on your device. '
            'Nothing you type leaves your phone.',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

String _deviceSummary(DeviceCapabilities capabilities) {
  final isFast = capabilities.accelerators
      .any((accelerator) => accelerator.type == AcceleratorType.gpu);
  return '${formatBytes(capabilities.memory.totalBytes)} RAM · '
      '${formatBytes(capabilities.storage.freeBytes)} free · '
      '${isFast ? 'Fast' : 'Standard'}';
}

String _creativityLabel(double temperature) {
  if (temperature < 0.4) return 'Focused';
  if (temperature < 1.0) return 'Balanced';
  return 'Creative';
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: scheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
