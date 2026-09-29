import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:staylocal/data/repositories/device_capability_repository.dart';
import 'package:staylocal/models/device_capabilities.dart';
import 'package:staylocal/providers/device_capability_providers.dart';
import 'package:staylocal/providers/model_download_providers.dart';

import 'package:staylocal/main.dart';
import 'fakes/fake_model_download_repository.dart';

const int _gb = 1024 * 1024 * 1024;

class _TestDeviceCapabilityRepository implements DeviceCapabilityRepository {
  const _TestDeviceCapabilityRepository();

  @override
  Future<MemoryInfo> memory() async =>
      MemoryInfo(totalBytes: 8 * _gb, availableBytes: 4 * _gb);

  @override
  Future<StorageInfo> storage() async =>
      StorageInfo(freeBytes: 32 * _gb, totalBytes: 128 * _gb);

  @override
  Future<GpuProbe> gpu() async =>
      const GpuProbe(renderer: 'Test', vulkanVersion: '1.1');

  @override
  Future<DeviceIdentity> identity() async => const DeviceIdentity(
        manufacturer: 'Test',
        model: 'Test',
        board: 'Test',
        hardware: 'Test',
        abis: ['arm64-v8a'],
        osVersion: 'Android 16',
      );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('home has menu, power action, greeting and composer',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StayLocalApp()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Menu'), findsOneWidget);
    // Library lives in the drawer now; the AppBar keeps only the power
    // load/unload action (disabled with no model downloaded).
    expect(find.byTooltip('Models'), findsNothing);
    expect(find.text('How can I help?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Browse models'), findsOneWidget);
  });

  testWidgets('drawer shows new chat, conversations and settings',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StayLocalApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    expect(find.text('New chat'), findsOneWidget);
    expect(find.text('No chats yet'), findsOneWidget);
    expect(find.text('Models'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('drawer models entry opens models catalog',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceCapabilityRepositoryProvider.overrideWithValue(
            const _TestDeviceCapabilityRepository(),
          ),
          modelDownloadRepositoryProvider.overrideWithValue(
            FakeModelDownloadRepository(),
          ),
        ],
        child: const StayLocalApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Models'));
    // The catalog keeps streams alive, so settle is unbounded here.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Drawer closed behind us: 'Models' is the catalog AppBar title.
    expect(find.text('Models'), findsWidgets);
  });

  testWidgets('theme mode switches from settings via drawer',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StayLocalApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('persisted theme mode is restored on launch',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'theme_mode': 'dark',
    });

    await tester.pumpWidget(const ProviderScope(child: StayLocalApp()));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
