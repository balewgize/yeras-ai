import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:staylocal/data/repositories/device_capability_repository.dart';
import 'package:staylocal/models/device_capabilities.dart';
import 'package:staylocal/providers/device_capability_providers.dart';
import 'package:staylocal/utils/format.dart';
import 'package:staylocal/main.dart';
import 'package:staylocal/screens/device_info_screen.dart';

const int _gb = 1024 * 1024 * 1024;

class _FakeDeviceCapabilityRepository implements DeviceCapabilityRepository {
  const _FakeDeviceCapabilityRepository();

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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('formatBytes', () {
    test('formats gigabytes with one decimal', () {
      expect(formatBytes(8 * _gb), '8.6 GB');
      expect(formatBytes(2899102924), '2.9 GB');
    });

    test('formats megabytes without decimals', () {
      expect(formatBytes(512 * 1024 * 1024), '537 MB');
    });
  });

  group('DeviceCapabilities.detect', () {
    test('composes accelerators for a Snapdragon-class device', () {
      final capabilities = DeviceCapabilities.detect(
        memory: MemoryInfo(
          totalBytes: 8 * _gb,
          availableBytes: 4 * _gb,
        ),
        storage: StorageInfo(freeBytes: 32 * _gb, totalBytes: 128 * _gb),
        gpu: GpuProbe(renderer: 'Adreno (TM) 810', vulkanVersion: '1.1'),
        identity: DeviceIdentity(
          manufacturer: 'Samsung',
          model: 'SM-A366B',
          board: 'A36XQ',
          hardware: 'qcom',
          abis: const ['arm64-v8a'],
          osVersion: 'Android 16',
        ),
        cpuCores: 8,
      );

      expect(capabilities.accelerators.length, 3);
      expect(capabilities.accelerators[0].name, 'CPU');
      expect(capabilities.accelerators[0].status, AcceleratorStatus.usedByEngine);
      expect(capabilities.accelerators[1].name, 'Adreno (TM) 810');
      expect(capabilities.accelerators[1].detail, 'Vulkan 1.1');
      expect(
        capabilities.accelerators[1].status,
        AcceleratorStatus.pendingVerification,
      );
      expect(capabilities.accelerators[2].name, 'Hexagon NPU');
      expect(capabilities.accelerators[2].status, AcceleratorStatus.notUsed);
      expect(
        capabilities.conservativeModelBudgetBytes,
        4 * _gb * 7 ~/ 10,
      );
    });

    test('omits the NPU row when the chipset has no supported NPU', () {
      final capabilities = DeviceCapabilities.detect(
        memory: MemoryInfo(
          totalBytes: 6 * _gb,
          availableBytes: 2 * _gb,
        ),
        storage: StorageInfo(freeBytes: 10 * _gb, totalBytes: 64 * _gb),
        gpu: GpuProbe(renderer: 'Mali-G68', vulkanVersion: '1.1'),
        identity: DeviceIdentity(
          manufacturer: 'Samsung',
          model: 'SM-A556B',
          board: 's5e8825',
          hardware: 'exynos',
          abis: const ['arm64-v8a'],
          osVersion: 'Android 15',
        ),
        cpuCores: 8,
      );

      expect(capabilities.accelerators.length, 2);
      expect(capabilities.accelerators[1].name, 'Mali-G68');
    });

    test('omits the GPU row when the probe finds nothing', () {
      final capabilities = DeviceCapabilities.detect(
        memory: MemoryInfo(
          totalBytes: 4 * _gb,
          availableBytes: 2 * _gb,
        ),
        storage: StorageInfo(freeBytes: 8 * _gb, totalBytes: 32 * _gb),
        gpu: const GpuProbe(),
        identity: DeviceIdentity(
          manufacturer: 'Test',
          model: 'T1000',
          board: 't1000',
          hardware: 'test',
          abis: const ['arm64-v8a'],
          osVersion: 'Android 14',
        ),
        cpuCores: 4,
      );

      expect(capabilities.accelerators.length, 1);
      expect(capabilities.accelerators.single.type, AcceleratorType.cpu);
    });
  });

  testWidgets('device screen shows detected values', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceCapabilityRepositoryProvider.overrideWithValue(
            _FakeDeviceCapabilityRepository(),
          ),
        ],
        child: const MaterialApp(home: DeviceInfoScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Samsung'), findsOneWidget);
    expect(find.text('SM-A366B'), findsOneWidget);
    expect(find.text('Qualcomm'), findsOneWidget);
    expect(find.text('8.6 GB'), findsOneWidget);
    expect(find.text('4.3 GB'), findsOneWidget);
    expect(find.text('≤ 3.0 GB'), findsOneWidget);
    expect(find.text('34.4 GB'), findsOneWidget);
    expect(find.text('137 GB'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Hexagon NPU'),
      200,
      scrollable: scrollable,
    );

    expect(find.text('Adreno (TM) 810'), findsOneWidget);
    expect(find.text('Vulkan 1.1'), findsOneWidget);
    expect(find.text('Hexagon NPU'), findsOneWidget);
    expect(find.text('Used for inference'), findsOneWidget);
  });

  testWidgets('settings links to the device screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceCapabilityRepositoryProvider.overrideWithValue(
            _FakeDeviceCapabilityRepository(),
          ),
        ],
        child: const StayLocalApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Device details'));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Adreno (TM) 810'),
      200,
      scrollable: scrollable,
    );

    expect(find.text('Accelerators'), findsOneWidget);
    expect(find.text('Adreno (TM) 810'), findsOneWidget);
  });
}
