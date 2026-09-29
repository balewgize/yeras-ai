import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:staylocal/data/repositories/device_capability_repository.dart';
import 'package:staylocal/data/repositories/model_catalog_repository.dart';
import 'package:staylocal/main.dart';
import 'package:staylocal/models/device_capabilities.dart';
import 'package:staylocal/models/model_download.dart';
import 'package:staylocal/providers/device_capability_providers.dart';
import 'package:staylocal/providers/foreground_generation_providers.dart';
import 'package:staylocal/providers/inference_providers.dart';
import 'package:staylocal/providers/model_catalog_providers.dart';
import 'package:staylocal/providers/model_download_providers.dart';
import 'package:staylocal/services/foreground_generation.dart';

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

/// Records platform start/stop calls while reusing the real service's
/// dedup and error semantics (channel calls replaced by hooks).
ForegroundGenerationService _recordingService(List<String> events) {
  return ForegroundGenerationService(
    isAndroidCheck: () => true,
    onPlatformStart: () => events.add('start'),
    onPlatformStop: () => events.add('stop'),
  );
}

Finder _powerButton(String verb) => find.byWidgetPredicate(
      (widget) =>
          widget is IconButton &&
          (widget.tooltip ?? '').startsWith('$verb ') &&
          widget.onPressed != null,
    );

Future<void> _pumpApp(
  WidgetTester tester, {
  required FakeModelDownloadRepository downloads,
  required FakeInferenceRepository inference,
  required List<String> foregroundEvents,
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
        foregroundGenerationProvider.overrideWithValue(
          _recordingService(foregroundEvents),
        ),
      ],
      child: const StayLocalApp(),
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

void main() {
  const channel = MethodChannel('staylocal/foreground_generation');

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('service', () {
    testWidgets('start/stop hit the channel once each and dedup repeats',
        (WidgetTester tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );

      final service = ForegroundGenerationService(isAndroidCheck: () => true);
      expect(service.isSupported, isTrue);

      await service.start();
      await service.start();
      await service.stop();
      await service.stop();

      // First start also fires the one-shot notification permission ask.
      expect(calls, [
        'requestNotificationPermission',
        'startGeneration',
        'stopGeneration',
      ]);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });

    testWidgets('unsupported platforms never touch the channel',
        (WidgetTester tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );

      final service = ForegroundGenerationService();
      expect(service.isSupported, isFalse);

      await service.start();
      await service.stop();
      expect(calls, isEmpty);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });

    testWidgets('channel failures are swallowed and retried cleanly',
        (WidgetTester tester) async {
      final calls = <String>[];
      var failNextStart = true;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async {
          calls.add(call.method);
          if (call.method == 'startGeneration' && failNextStart) {
            failNextStart = false;
            throw PlatformException(code: 'foreground_generation_error');
          }
          return null;
        },
      );

      final service = ForegroundGenerationService(isAndroidCheck: () => true);
      // The failed start must not throw and must reset the running flag.
      await service.start();
      // The retry (no permission re-ask) starts the service.
      await service.start();
      await service.stop();

      expect(calls, [
        'requestNotificationPermission',
        'startGeneration',
        'startGeneration',
        'stopGeneration',
      ]);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });

    testWidgets('missing plugin (tests, non-Android hosts) is swallowed',
        (WidgetTester tester) async {
      // A raw handler answering with no reply bytes is exactly what a host
      // without the Kotlin side does: invokeMethod then throws
      // MissingPluginException. Neither call may propagate it (or hang).
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        channel.name,
        (ByteData? message) async => null,
      );

      final service = ForegroundGenerationService(isAndroidCheck: () => true);
      await service.start();
      await service.stop();

      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        channel.name,
        null,
      );
    });
  });

  group('chat controller holds the service only while busy', () {
    testWidgets('load and generate each bracket with start/stop',
        (WidgetTester tester) async {
      final downloads = FakeModelDownloadRepository();
      final inference = FakeInferenceRepository()
        ..tokenScript = const <String>['Hi ', 'there'];
      final events = <String>[];
      await _pumpApp(
        tester,
        downloads: downloads,
        inference: inference,
        foregroundEvents: events,
      );
      downloads.emit('llama-3.2-1b', _ready('/cache/model.gguf', 808000000));
      await tester.pumpAndSettle();
      expect(events, isEmpty);

      await tester.tap(_powerButton('Load'));
      await tester.pumpAndSettle();
      expect(events, ['start', 'stop']);

      await _send(tester, 'Hello');
      expect(events, ['start', 'stop', 'start', 'stop']);
    });

    testWidgets('stopping mid-generation stops the service promptly',
        (WidgetTester tester) async {
      final downloads = FakeModelDownloadRepository();
      final inference = FakeInferenceRepository()
        ..chatGate = Completer<void>()
        ..tokenScript = const <String>['partial'];
      final events = <String>[];
      await _pumpApp(
        tester,
        downloads: downloads,
        inference: inference,
        foregroundEvents: events,
      );
      downloads.emit('llama-3.2-1b', _ready('/cache/model.gguf', 808000000));
      await tester.pumpAndSettle();
      await tester.tap(_powerButton('Load'));
      await tester.pumpAndSettle();
      expect(events, ['start', 'stop']);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      expect(events, ['start', 'stop', 'start']);

      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();
      expect(events, ['start', 'stop', 'start', 'stop']);

      // The cancelled stream unwinding must not stop the service twice.
      inference.chatGate!.complete();
      await tester.pumpAndSettle();
      expect(events, ['start', 'stop', 'start', 'stop']);
    });

    testWidgets('new chat mid-generation stops the service',
        (WidgetTester tester) async {
      final downloads = FakeModelDownloadRepository();
      final inference = FakeInferenceRepository()
        ..chatGate = Completer<void>()
        ..tokenScript = const <String>['partial'];
      final events = <String>[];
      await _pumpApp(
        tester,
        downloads: downloads,
        inference: inference,
        foregroundEvents: events,
      );
      downloads.emit('llama-3.2-1b', _ready('/cache/model.gguf', 808000000));
      await tester.pumpAndSettle();
      await tester.tap(_powerButton('Load'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      expect(events, ['start', 'stop', 'start']);

      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New chat'));
      await tester.pump();
      expect(events, ['start', 'stop', 'start', 'stop']);

      inference.chatGate!.complete();
      await tester.pumpAndSettle();
      expect(events, ['start', 'stop', 'start', 'stop']);
    });
  });
}
