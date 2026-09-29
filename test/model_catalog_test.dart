import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:staylocal/data/repositories/device_capability_repository.dart';
import 'package:staylocal/data/repositories/model_catalog_repository.dart';
import 'package:staylocal/models/device_capabilities.dart';
import 'package:staylocal/models/model_catalog.dart';
import 'package:staylocal/providers/device_capability_providers.dart';
import 'package:staylocal/providers/model_download_providers.dart';
import 'package:staylocal/main.dart';

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
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('catalog contents', () {
    test('contains a curated 5-8 model list in the 1-4GB range', () async {
      final models = await const StaticModelCatalogRepository().models();

      expect(models.length, inInclusiveRange(5, 8));
      for (final model in models) {
        expect(model.sizeBytes, greaterThan(500 * 1000 * 1000));
        expect(model.sizeBytes, lessThan(4200 * 1000 * 1000));
        expect(model.downloadUrl, startsWith('https://'));
        expect(model.downloadUrl, endsWith('.gguf'));
        expect(model.description, isNotEmpty);
      }
    });

    test('covers the expected families', () async {
      final models = await const StaticModelCatalogRepository().models();
      final names = models.map((model) => model.name).toList();

      expect(names, contains('Qwen2.5 1.5B'));
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

      expect(fits['llama-3.2-1b'], ModelFit.recommended);
      expect(fits['qwen2.5-1.5b'], ModelFit.recommended);
      expect(fits['gemma-2-2b'], ModelFit.willBeSlow);
      expect(fits['qwen2.5-3b'], ModelFit.willBeSlow);
      expect(fits['llama-3.2-3b'], ModelFit.willBeSlow);
      expect(fits['phi-3.5-mini'], ModelFit.willBeSlow);
      expect(fits['llama-3.1-8b'], ModelFit.wontFit);

      final counts = fits.values.toList();
      expect(
        counts.where((fit) => fit == ModelFit.recommended).length,
        2,
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
        child: const StayLocalApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    final modelsTile = find.descendant(
      of: find.byType(ListTile),
      matching: find.text('Models'),
    );
    expect(modelsTile, findsOneWidget);
    await tester.tap(modelsTile);
    await tester.pumpAndSettle();

    expect(find.text('Qwen2.5 1.5B'), findsOneWidget);
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
        child: const StayLocalApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New chat'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Browse models'));
    await tester.pumpAndSettle();

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
