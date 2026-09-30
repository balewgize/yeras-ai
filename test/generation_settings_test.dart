import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yeras_ai/data/repositories/device_capability_repository.dart';
import 'package:yeras_ai/data/repositories/model_catalog_repository.dart';
import 'package:yeras_ai/main.dart';
import 'package:yeras_ai/models/device_capabilities.dart';
import 'package:yeras_ai/models/model_download.dart';
import 'package:yeras_ai/providers/device_capability_providers.dart';
import 'package:yeras_ai/providers/generation_settings_providers.dart';
import 'package:yeras_ai/providers/inference_providers.dart';
import 'package:yeras_ai/providers/model_catalog_providers.dart';
import 'package:yeras_ai/providers/model_download_providers.dart';

import 'fakes/fake_inference_repository.dart';
import 'fakes/fake_model_download_repository.dart';

const int _gb = 1024 * 1024 * 1024;

class _MidRangeDeviceCapabilityRepository
    implements DeviceCapabilityRepository {
  const _MidRangeDeviceCapabilityRepository();

  @override
  Future<MemoryInfo> memory() async =>
      MemoryInfo(totalBytes: 8 * _gb, availableBytes: 4 * _gb);

  @override
  Future<StorageInfo> storage() async =>
      StorageInfo(freeBytes: 32 * _gb, totalBytes: 128 * _gb);

  @override
  Future<GpuProbe> gpu() async =>
      const GpuProbe(renderer: 'Adreno (TM) 810', vulkanVersion: '1.1');

  @override
  Future<DeviceIdentity> identity() async => const DeviceIdentity(
        manufacturer: 'Samsung',
        model: 'SM-A366B',
        board: 'A36XQ',
        hardware: 'qcom',
        abis: ['arm64-v8a'],
        osVersion: 'Android 16',
      );
}

const String _fixtureCatalog = '''
[
  {
    "id": "llama-3.2-1b",
    "name": "Llama 3.2 1B",
    "parameter_count_label": "1B",
    "parameter_count_in_billions": 1,
    "quantization": "Q4_K_M",
    "context_length": 8192,
    "size_mb": 808,
    "min_ram_gb": 4,
    "description": "Test fixture",
    "download_url": "https://example.com/a.gguf"
  }
]
''';

ModelDownloadState _ready(String path, int bytes) => ModelDownloadState(
      stage: DownloadStage.ready,
      receivedBytes: bytes,
      totalBytes: bytes,
      filePath: path,
    );

Finder _powerButton(String verb) => find.byWidgetPredicate(
      (widget) =>
          widget is IconButton &&
          (widget.tooltip ?? '').startsWith('$verb ') &&
          widget.onPressed != null,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_seen': true,
    });
  });

  group('generation settings provider', () {
    Future<ProviderContainer> pumpScope(WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: SizedBox()),
      );
      final container =
          ProviderScope.containerOf(tester.element(find.byType(SizedBox)));
      // Build the provider up front so the async restore finishes
      // during the settle below (reads after settle alone would race it).
      container.read(generationSettingsProvider);
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('defaults are temperature 0.8 and context 2048',
        (WidgetTester tester) async {
      final container = await pumpScope(tester);
      final settings = container.read(generationSettingsProvider);
      expect(settings.temperature, 0.8);
      expect(settings.contextSize, 2048);
      expect(settings.isDefault, isTrue);
    });

    testWidgets('temperature persists and clamps to range',
        (WidgetTester tester) async {
      final container = await pumpScope(tester);

      await container
          .read(generationSettingsProvider.notifier)
          .setTemperature(0.2);
      expect(
        container.read(generationSettingsProvider).temperature,
        0.2,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('generation_temperature'), 0.2);

      // Out of range clamps instead of storing garbage.
      await container
          .read(generationSettingsProvider.notifier)
          .setTemperature(99);
      expect(
        container.read(generationSettingsProvider).temperature,
        GenerationSettings.maxTemperature,
      );
    });

    testWidgets('context size accepts only listed options',
        (WidgetTester tester) async {
      final container = await pumpScope(tester);

      await container
          .read(generationSettingsProvider.notifier)
          .setContextSize(4096);
      expect(container.read(generationSettingsProvider).contextSize, 4096);

      // Unknown sizes are ignored, never persisted.
      await container
          .read(generationSettingsProvider.notifier)
          .setContextSize(9999);
      expect(container.read(generationSettingsProvider).contextSize, 4096);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('generation_context_size'), 4096);
    });

    testWidgets('reset restores defaults and clears storage',
        (WidgetTester tester) async {
      final container = await pumpScope(tester);

      await container
          .read(generationSettingsProvider.notifier)
          .setTemperature(0.2);
      await container
          .read(generationSettingsProvider.notifier)
          .setContextSize(4096);
      await container.read(generationSettingsProvider.notifier).resetDefaults();

      final settings = container.read(generationSettingsProvider);
      expect(settings.isDefault, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('generation_temperature'), isFalse);
      expect(prefs.containsKey('generation_context_size'), isFalse);
    });

    testWidgets('saved values are restored on launch',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'onboarding_seen': true,
        'generation_temperature': 0.3,
        'generation_context_size': 4096,
      });
      final container = await pumpScope(tester);
      final settings = container.read(generationSettingsProvider);
      expect(settings.temperature, 0.3);
      expect(settings.contextSize, 4096);
    });
  });

  group('advanced panel', () {
    testWidgets('collapsed by default and edits apply to generation',
        (WidgetTester tester) async {
      final downloads = FakeModelDownloadRepository();
      final inference = FakeInferenceRepository()
        ..tokenScript = const <String>['Hi'];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceCapabilityRepositoryProvider.overrideWithValue(
              const _MidRangeDeviceCapabilityRepository(),
            ),
            modelCatalogRepositoryProvider.overrideWithValue(
              StaticModelCatalogRepository(
                readCatalogJson: () async => _fixtureCatalog,
              ),
            ),
            modelDownloadRepositoryProvider.overrideWithValue(downloads),
            inferenceRepositoryProvider.overrideWithValue(inference),
          ],
          child: const YerasAIApp(),
        ),
      );
      await tester.pumpAndSettle();
      downloads.emit('llama-3.2-1b', _ready('/cache/model.gguf', 808000000));
      await tester.pumpAndSettle();

      // Off by default: options hidden until expanded.
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Temperature'), findsNothing);
      await tester.tap(find.text('Generation options'));
      await tester.pumpAndSettle();
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('Context length'), findsOneWidget);

      // Pick a non-default context length from the panel.
      await tester.scrollUntilVisible(find.text('4096'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('4096'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Custom'), findsOneWidget);

      // Back home, load, chat: the custom values reach the engine.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();
      await tester.tap(_powerButton('Load'));
      await tester.pumpAndSettle();
      expect(inference.lastContextSize, 4096);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(inference.lastTemperature, 0.8);
    });
  });
}
