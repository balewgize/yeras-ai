import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yeras_ai/data/repositories/device_capability_repository.dart';
import 'package:yeras_ai/data/repositories/inference_repository.dart';
import 'package:yeras_ai/data/repositories/model_catalog_repository.dart';
import 'package:yeras_ai/main.dart';
import 'package:yeras_ai/models/device_capabilities.dart';
import 'package:yeras_ai/models/inference.dart';
import 'package:yeras_ai/models/model_download.dart';
import 'package:yeras_ai/providers/device_capability_providers.dart';
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

/// Hermetic catalog fixture: bypasses the real `rootBundle` asset, which
/// does not resolve reliably across multiple widget tests in one file.
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
  },
  {
    "id": "qwen2.5-1.5b",
    "name": "Qwen 2.5 1.5B",
    "parameter_count_label": "1.5B",
    "parameter_count_in_billions": 1.5,
    "quantization": "Q4_K_M",
    "context_length": 8192,
    "size_mb": 1000,
    "min_ram_gb": 6,
    "description": "Test fixture",
    "download_url": "https://example.com/b.gguf"
  }
]
''';

ModelDownloadState _ready(String path, int bytes) => ModelDownloadState(
      stage: DownloadStage.ready,
      receivedBytes: bytes,
      totalBytes: bytes,
      filePath: path,
    );

Future<void> _pumpApp(
  WidgetTester tester, {
  required FakeModelDownloadRepository downloads,
  required FakeInferenceRepository inference,
}) async {
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
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.byTooltip('Send'));
  await tester.pumpAndSettle();
}

Finder _disabledSend() => find.byWidgetPredicate(
      (widget) =>
          widget is IconButton &&
          widget.tooltip == 'Send' &&
          widget.onPressed == null,
    );

Finder _enabledSend() => find.byWidgetPredicate(
      (widget) =>
          widget is IconButton &&
          widget.tooltip == 'Send' &&
          widget.onPressed != null,
    );

/// Inline Load action above the composer (needsLoad state).
Finder _loadCta(String modelName) => find.ancestor(
      of: find.textContaining('Load $modelName'),
      matching: find.byType(FilledButton),
    );

/// Top-bar power icon that loads/unloads the active model.
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

  testWidgets('intentional load gate: load, chat, unload, blocked again',
      (WidgetTester tester) async {
    final downloads = FakeModelDownloadRepository();
    final inference = FakeInferenceRepository()
      ..tokenScript = const <String>['Hi ', 'there']
      ..scriptResult = const InferenceResult(
        text: 'Hi there',
        completionTokens: 2,
        tokensPerSecond: 21.5,
      );
    await _pumpApp(tester, downloads: downloads, inference: inference);
    downloads.emit('llama-3.2-1b', _ready('/cache/model.gguf', 808000000));
    await tester.pumpAndSettle();

    // Gated: explicit Load action is offered, Send is disabled.
    expect(find.text('Llama 3.2 1B'), findsWidgets);
    expect(_loadCta('Llama 3.2 1B'), findsOneWidget);
    expect(_disabledSend(), findsOneWidget);

    // Intentional load reports success inline; Send unlocks once typed.
    await tester.tap(_loadCta('Llama 3.2 1B'));
    await tester.pumpAndSettle();
    expect(find.textContaining('loaded · ready offline'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    expect(_enabledSend(), findsOneWidget);

    // Chat streams the reply and reuses the loaded model.
    await _send(tester, 'Hello');
    expect(find.text('Hi there'), findsOneWidget);
    expect(find.textContaining('21.5 tok/s'), findsOneWidget);
    expect(inference.loadCalls, 1);

    await _send(tester, 'Again');
    expect(inference.loadCalls, 1);
    expect(inference.chatHistories.length, 2);
    expect(inference.chatHistories[1].length, 3);

    // Unload frees memory and re-arms the gate.
    await tester.tap(_powerButton('Unload'));
    await tester.pumpAndSettle();
    expect(find.textContaining('unloaded · memory freed'), findsOneWidget);
    expect(inference.unloadCalls, 1);
    expect(find.text('Load Llama 3.2 1B to start'), findsOneWidget);
    expect(_disabledSend(), findsOneWidget);
  });

  testWidgets('failed load reports inline with Send still blocked',
      (WidgetTester tester) async {
    final downloads = FakeModelDownloadRepository();
    final inference = FakeInferenceRepository()
      ..loadError = const ModelTooLargeException('Too large for this phone.');
    await _pumpApp(tester, downloads: downloads, inference: inference);
    downloads.emit('llama-3.2-1b', _ready('/cache/model.gguf', 808000000));
    await tester.pumpAndSettle();

    await tester.tap(_loadCta('Llama 3.2 1B'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Load failed'), findsOneWidget);
    expect(inference.loadCalls, 1);
    expect(_disabledSend(), findsOneWidget);
  });

  testWidgets('switching models requires loading the new pick',
      (WidgetTester tester) async {
    final downloads = FakeModelDownloadRepository();
    final inference = FakeInferenceRepository();
    await _pumpApp(tester, downloads: downloads, inference: inference);
    downloads.emit('llama-3.2-1b', _ready('/cache/a.gguf', 808000000));
    downloads.emit('qwen2.5-1.5b', _ready('/cache/b.gguf', 1000000000));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Llama 3.2 1B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qwen 2.5 1.5B').last);
    await tester.pumpAndSettle();
    expect(find.text('Qwen 2.5 1.5B'), findsWidgets);

    // The new pick is not auto-loaded: gate is armed until explicit load.
    expect(_loadCta('Qwen 2.5 1.5B'), findsOneWidget);
    expect(_disabledSend(), findsOneWidget);

    await tester.tap(_powerButton('Load'));
    await tester.pumpAndSettle();
    await _send(tester, 'Hi');
    expect(inference.lastModelId, 'qwen2.5-1.5b');
  });

  testWidgets('stop cancels an in-flight generation',
      (WidgetTester tester) async {
    final downloads = FakeModelDownloadRepository();
    final inference = FakeInferenceRepository()
      ..chatGate = Completer<void>()
      ..tokenScript = const <String>['partial'];
    await _pumpApp(tester, downloads: downloads, inference: inference);
    downloads.emit('llama-3.2-1b', _ready('/cache/model.gguf', 808000000));
    await tester.pumpAndSettle();
    await tester.tap(_powerButton('Load'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('Stop'), findsOneWidget);
    await tester.tap(find.byTooltip('Stop'));
    await tester.pump();
    expect(inference.stopCalls, 1);

    inference.chatGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Send'), findsOneWidget);
  });

  testWidgets('context-full error offers starting a new chat',
      (WidgetTester tester) async {
    final downloads = FakeModelDownloadRepository();
    final inference = FakeInferenceRepository()
      ..chatError = StateError('prompt too long for n_ctx, KV cache full');
    await _pumpApp(tester, downloads: downloads, inference: inference);
    downloads.emit('llama-3.2-1b', _ready('/cache/model.gguf', 808000000));
    await tester.pumpAndSettle();
    await tester.tap(_powerButton('Load'));
    await tester.pumpAndSettle();

    await _send(tester, 'Hello');
    expect(find.textContaining('outgrew'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'New chat'));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsNothing);
    expect(find.textContaining('outgrew'), findsNothing);
  });
}
