import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:staylocal/data/repositories/device_capability_repository.dart';
import 'package:staylocal/data/repositories/inference_repository.dart';
import 'package:staylocal/main.dart';
import 'package:staylocal/models/device_capabilities.dart';
import 'package:staylocal/models/inference.dart';
import 'package:staylocal/models/model_catalog.dart';
import 'package:staylocal/models/model_download.dart';
import 'package:staylocal/providers/device_capability_providers.dart';
import 'package:staylocal/providers/inference_providers.dart';
import 'package:staylocal/providers/model_download_providers.dart';

import 'fakes/fake_model_download_repository.dart';

class _MidRangeDeviceCapabilityRepository
    implements DeviceCapabilityRepository {
  const _MidRangeDeviceCapabilityRepository();

  @override
  Future<MemoryInfo> memory() async => MemoryInfo(
    totalBytes: 8 * 1024 * 1024 * 1024,
    availableBytes: 4 * 1024 * 1024 * 1024,
  );

  @override
  Future<StorageInfo> storage() async => StorageInfo(
    freeBytes: 32 * 1024 * 1024 * 1024,
    totalBytes: 128 * 1024 * 1024 * 1024,
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

class _FakeInferenceRepository implements InferenceRepository {
  LoadedModelInfo? loadedInfo;
  Object? loadError;
  List<String> tokenScript = const <String>[];
  InferenceResult? scriptResult;
  int stopCalls = 0;
  int unloadCalls = 0;

  @override
  Future<LoadedModelInfo> loadModel({
    required CatalogModel model,
    required String filePath,
    required int fileBytes,
    required DeviceCapabilities capabilities,
  }) async {
    if (loadError != null) throw loadError!;
    return loadedInfo!;
  }

  @override
  Future<InferenceResult> generate(
    String prompt, {
    required void Function(String token) onToken,
  }) async {
    for (final token in tokenScript) {
      onToken(token);
    }
    return scriptResult ??
        const InferenceResult(text: '', completionTokens: 0);
  }

  @override
  void cancelGeneration() => stopCalls++;

  @override
  Future<void> unload() async => unloadCalls++;

  @override
  Future<void> dispose() async {}
}

Future<void> _openDebugScreen(
  WidgetTester tester, {
  required FakeModelDownloadRepository downloads,
  required _FakeInferenceRepository inference,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceCapabilityRepositoryProvider.overrideWithValue(
          const _MidRangeDeviceCapabilityRepository(),
        ),
        modelDownloadRepositoryProvider.overrideWithValue(downloads),
        inferenceRepositoryProvider.overrideWithValue(inference),
      ],
      child: const StayLocalApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(ListTile),
      matching: find.text('Models'),
    ),
  );
  await tester.pumpAndSettle();

  downloads.emit(
    'llama-3.2-1b',
    const ModelDownloadState(
      stage: DownloadStage.ready,
      receivedBytes: 810000000,
      totalBytes: 810000000,
      filePath: '/cache/models/model.gguf',
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Test'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('debug screen streams raw output with tokens per second',
      (WidgetTester tester) async {
    final downloads = FakeModelDownloadRepository();
    final inference = _FakeInferenceRepository()
      ..loadedInfo = const LoadedModelInfo(
        modelName: 'Llama 3.2 1B',
        filePath: '/cache/models/model.gguf',
        fileBytes: 810000000,
        acceleratorLabel: 'GPU (Adreno (TM) 810 · Vulkan 1.1) · full offload',
        contextSize: 2048,
      )
      ..tokenScript = const <String>['on-device ', 'OK']
      ..scriptResult = const InferenceResult(
        text: 'on-device OK',
        completionTokens: 2,
        tokensPerSecond: 18.2,
      );

    await _openDebugScreen(
      tester,
      downloads: downloads,
      inference: inference,
    );

    expect(find.text('Debug inference'), findsOneWidget);
    expect(find.text('Llama 3.2 1B'), findsOneWidget);
    expect(find.textContaining('full offload'), findsOneWidget);
    expect(find.text('on-device OK'), findsOneWidget);
    expect(find.text('Done · 2 tokens · 18.2 tok/s'), findsOneWidget);
  });

  testWidgets('an oversized model is refused with a clear message, no crash',
      (WidgetTester tester) async {
    final downloads = FakeModelDownloadRepository();
    final inference = _FakeInferenceRepository()
      ..loadError = const ModelTooLargeException(
        'Llama 3.1 8B needs about 3.9 GB to load, but only about 2.8 GB is '
        'safely usable for models on this device. Loading it anyway would '
        'likely crash the app.',
      );

    await _openDebugScreen(
      tester,
      downloads: downloads,
      inference: inference,
    );

    expect(find.textContaining('safely usable'), findsOneWidget);
    expect(find.text('Run again'), findsOneWidget);
  });
}
