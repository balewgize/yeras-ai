import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/generation_settings_providers.dart';
import '../providers/theme_controller.dart';
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
          const SectionHeader('Models'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Models'),
            subtitle: Text(
              'Curated list for this device',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: scheme.onSurfaceVariant,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ModelCatalogScreen(),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const SectionHeader('Device'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Device details'),
            subtitle: Text(
              'RAM, storage, and accelerator detection',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: scheme.onSurfaceVariant,
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
            title: const Text('Generation options'),
            subtitle: Text(
              settings.isDefault
                  ? 'Defaults · temperature ${GenerationSettings.defaultTemperature}, context ${GenerationSettings.defaultContextSize}'
                  : 'Custom · temperature ${settings.temperature.toStringAsFixed(1)}, context ${settings.contextSize}',
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
                      'Temperature',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    settings.temperature.toStringAsFixed(1),
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
                label: settings.temperature.toStringAsFixed(1),
                onChanged: (value) {
                  ref
                      .read(generationSettingsProvider.notifier)
                      .setTemperature(value);
                },
              ),
              Text(
                'Lower is focused and repeatable, higher is more creative. '
                'Applies to the next reply.',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Context length',
                  style: textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [
                  for (final size in GenerationSettings.contextOptions)
                    ButtonSegment(value: size, label: Text('$size')),
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
                'memory. Takes effect the next time a model loads.',
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
