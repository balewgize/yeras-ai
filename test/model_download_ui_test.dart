import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:staylocal/data/repositories/device_capability_repository.dart';
import 'package:staylocal/main.dart';
import 'package:staylocal/models/device_capabilities.dart';
import 'package:staylocal/models/model_download.dart';
import 'package:staylocal/providers/device_capability_providers.dart';
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

Future<void> _openModelsScreen(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menu'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Models'));
  // The catalog keeps download streams alive, so settle never completes.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Widget _app(FakeModelDownloadRepository downloads) => ProviderScope(
  overrides: [
    deviceCapabilityRepositoryProvider.overrideWithValue(
      const _MidRangeDeviceCapabilityRepository(),
    ),
    modelDownloadRepositoryProvider.overrideWithValue(downloads),
  ],
  child: const StayLocalApp(),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Asset strings are cached in a completed future bound to the zone of
    // the first test; without clearing, later widget tests never resolve.
    rootBundle.clear();
  });

  testWidgets('download row shows live progress with a cancel control',
    (WidgetTester tester) async {
      final downloads = FakeModelDownloadRepository();
      await tester.pumpWidget(_app(downloads));
      await tester.pumpAndSettle();

      await _openModelsScreen(tester);

      expect(find.text('Download'), findsWidgets);

      await tester.tap(find.text('Download').first);
      await tester.pumpAndSettle();
      expect(downloads.starts, contains('llama-3.2-1b'));

      downloads.emit(
        'llama-3.2-1b',
        const ModelDownloadState(
          stage: DownloadStage.downloading,
          receivedBytes: 300000000,
          totalBytes: 810000000,
          speedBytesPerSecond: 2400000,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('300 MB of 810 MB · 2.4 MB/s'), findsOneWidget);
      expect(find.text('Keep the app open to finish.'), findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator).first,
      );
      expect(progress.value, closeTo(0.37, 0.01));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(downloads.cancels, contains('llama-3.2-1b'));
    },
  );

  testWidgets('a stopped download shows N of X MB with a single Resume',
    (WidgetTester tester) async {
      final downloads = FakeModelDownloadRepository();
      await tester.pumpWidget(_app(downloads));
      await tester.pumpAndSettle();

      await _openModelsScreen(tester);

      downloads.emit(
        'llama-3.2-1b',
        const ModelDownloadState(
          stage: DownloadStage.stopped,
          receivedBytes: 300000000,
          totalBytes: 810000000,
          partialBytes: 300000000,
          errorMessage: 'Failed to download model.gguf: HTTP 503.',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('HTTP 503'), findsOneWidget);
      expect(find.text('300 MB of 810 MB'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);

      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(downloads.starts, contains('llama-3.2-1b'));
    },
  );

  testWidgets(
    'a partial download after reopening offers N of X MB and Resume',
    (WidgetTester tester) async {
      final downloads = FakeModelDownloadRepository();
      await tester.pumpWidget(_app(downloads));
      await tester.pumpAndSettle();

      await _openModelsScreen(tester);

      downloads.emit(
        'llama-3.2-1b',
        const ModelDownloadState(
          stage: DownloadStage.notDownloaded,
          partialBytes: 400000000,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('400 MB of 810 MB'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(downloads.starts, contains('llama-3.2-1b'));
    },
  );

  testWidgets('a downloaded model can be deleted with confirmation',
    (WidgetTester tester) async {
      final downloads = FakeModelDownloadRepository();
      await tester.pumpWidget(_app(downloads));
      await tester.pumpAndSettle();

      await _openModelsScreen(tester);

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

      expect(find.text('Downloaded · 810 MB'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Delete Llama 3.2 1B?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(downloads.deletes, contains('llama-3.2-1b'));
    },
  );
}
