import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yeras_ai/data/repositories/device_capability_repository.dart';
import 'package:yeras_ai/data/repositories/model_catalog_repository.dart';
import 'package:yeras_ai/models/device_capabilities.dart';
import 'package:yeras_ai/models/model_catalog.dart';
import 'package:yeras_ai/providers/device_capability_providers.dart';
import 'package:yeras_ai/providers/model_download_providers.dart';
import 'package:yeras_ai/main.dart';

import 'fakes/fake_model_download_repository.dart';

const int _gb = 1024 * 1024 * 1024;

class _MidRangeDeviceCapabilityRepository
    implements DeviceCapabilityRepository {
  const _MidRangeDeviceCapabilityRepository();

  @override
  Future<MemoryInfo> memory() async => MemoryInfo(
        totalBytes: 8 * _gb,
        availableBytes: 4 * _gb,
      );

  @override
  Future<StorageInfo> storage() async => StorageInfo(
        freeBytes: 32 * _gb,
        totalBytes: 128 * _gb,
      );

  @override
  Future<GpuProbe> gpu() async => const GpuProbe(
        renderer: 'Adreno (TM) 810',
        vulkanVersion: '1.1',
      );

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

DeviceCapabilities _midRangeCapabilities() => DeviceCapabilities.detect(
      memory: MemoryInfo(totalBytes: 8 * _gb, availableBytes: 4 * _gb),
      storage: StorageInfo(freeBytes: 32 * _gb, totalBytes: 128 * _gb),
      gpu: const GpuProbe(
        renderer: 'Adreno (TM) 810',
        vulkanVersion: '1.1',
      ),
      identity: const DeviceIdentity(
        manufacturer: 'Samsung',
        model: 'SM-A366B',
        board: 'A36XQ',
        hardware: 'qcom',
        abis: ['arm64-v8a'],
        osVersion: 'Android 16',
      ),
      cpuCores: 8,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_seen': true,
    });
    // Asset strings are cached in a completed future bound to the zone of
    // the first test; without clearing, later widget tests never resolve.
    rootBundle.clear();
  });

  group('catalog contents', () {
    test('contains a curated model list in the sub-GB to 4GB range', () async {
      final models = await const StaticModelCatalogRepository().models();

      expect(models.length, 9);
      for (final model in models) {
        expect(model.sizeBytes, greaterThan(300 * 1000 * 1000));
        expect(model.sizeBytes, lessThan(4200 * 1000 * 1000));
        expect(model.downloadUrl, startsWith('https://'));
        expect(model.downloadUrl, endsWith('.gguf'));
        expect(model.description, isNotEmpty);
      }
    });

    test('covers the expected families', () async {
      final models = await const StaticModelCatalogRepository().models();
      final names = models.map((model) => model.name).toList();

      expect(names, contains('Qwen 2.5 0.5B'));
      expect(names, contains('Qwen 2.5 1.5B'));
      expect(names, contains('DeepSeek R1 1.5B'));
      expect(names, contains('Gemma 2 2B'));
      expect(names, contains('Phi 3.5 Mini'));
      expect(names, contains('Llama 3.2 1B'));
      expect(names, contains('Llama 3.2 3B'));
      expect(names, contains('Llama 3.1 8B'));
    });
  });

  group('fit labels on a mid-range 8GB device', () {
    test('labels are honest for an A36-class phone', () async {
      final models = await const StaticModelCatalogRepository().models();
      final capabilities = _midRangeCapabilities();
      final fits = {
        for (final model in models)
          model.id: model.fitFor(capabilities),
      };

      expect(fits['qwen2.5-0.5b'], ModelFit.recommended);
      expect(fits['llama-3.2-1b'], ModelFit.recommended);
      expect(fits['qwen2.5-1.5b'], ModelFit.recommended);
      expect(fits['deepseek-r1-distill-qwen-1.5b'], ModelFit.recommended);
      expect(fits['gemma-2-2b'], ModelFit.willBeSlow);
      expect(fits['qwen2.5-3b'], ModelFit.willBeSlow);
      expect(fits['llama-3.2-3b'], ModelFit.willBeSlow);
      expect(fits['phi-3.5-mini'], ModelFit.willBeSlow);
      expect(fits['llama-3.1-8b'], ModelFit.wontFit);

      final counts = fits.values.toList();
      expect(
        counts.where((fit) => fit == ModelFit.recommended).length,
        4,
      );
      expect(
        counts.where((fit) => fit == ModelFit.willBeSlow).length,
        4,
      );
      expect(
        counts.where((fit) => fit == ModelFit.wontFit).length,
        1,
      );
    });

    test('a flagship with headroom still warns on big models', () async {
      final models = await const StaticModelCatalogRepository().models();
      final capabilities = DeviceCapabilities.detect(
        memory: MemoryInfo(
          totalBytes: 24 * _gb,
          availableBytes: 16 * _gb,
        ),
        storage: StorageInfo(
          freeBytes: 200 * _gb,
          totalBytes: 512 * _gb,
        ),
        gpu: const GpuProbe(
          renderer: 'Adreno 830',
          vulkanVersion: '1.3',
        ),
        identity: const DeviceIdentity(
          manufacturer: 'Google',
          model: 'Pixel 10',
          board: 'tensor_g5',
          hardware: 'tensor',
          abis: ['arm64-v8a'],
          osVersion: 'Android 16',
        ),
        cpuCores: 8,
      );
      final fits = {
        for (final model in models)
          model.id: model.fitFor(capabilities),
      };

      expect(fits['llama-3.1-8b'], ModelFit.willBeSlow);
      expect(
        fits.values.where((fit) => fit == ModelFit.wontFit),
        isEmpty,
      );
    });
  });

  testWidgets('catalog screen shows models with honest badges',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceCapabilityRepositoryProvider.overrideWithValue(
            const _MidRangeDeviceCapabilityRepository(),
          ),
          modelDownloadRepositoryProvider.overrideWithValue(
            FakeModelDownloadRepository(),
          ),
        ],
        child: const YerasAIApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Models'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Qwen 2.5 1.5B'), findsOneWidget);
    expect(find.text('Recommended'), findsWidgets);
    expect(
      find.textContaining('Labels are based on this device'),
      findsOneWidget,
    );

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Llama 3.1 8B'),
      300,
      scrollable: scrollable,
    );

    expect(find.text("Won't fit"), findsOneWidget);
  });

  testWidgets('chat empty state links to the catalog',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceCapabilityRepositoryProvider.overrideWithValue(
            const _MidRangeDeviceCapabilityRepository(),
          ),
          modelDownloadRepositoryProvider.overrideWithValue(
            FakeModelDownloadRepository(),
          ),
        ],
        child: const YerasAIApp(),
      ),
    );
    await tester.pumpAndSettle();

    final homeScroll = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Browse models'),
      100,
      scrollable: homeScroll,
    );
    await tester.tap(find.text('Browse models'));
    // The catalog keeps streams alive, so settle is unbounded here.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Models'), findsWidgets);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Phi 3.5 Mini'),
      300,
      scrollable: scrollable,
    );

    expect(find.text('Phi 3.5 Mini'), findsOneWidget);
  });
}
