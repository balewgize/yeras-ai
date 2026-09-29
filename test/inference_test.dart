import 'package:flutter_test/flutter_test.dart';

import 'package:staylocal/models/device_capabilities.dart';
import 'package:staylocal/models/inference.dart';

const int _gb = 1000 * 1000 * 1000;

DeviceCapabilities _a36Capabilities() => DeviceCapabilities.detect(
  memory: MemoryInfo(
    totalBytes: 8 * _gb,
    availableBytes: 4 * _gb,
  ),
  storage: StorageInfo(freeBytes: 32 * _gb, totalBytes: 128 * _gb),
  gpu: const GpuProbe(renderer: 'Adreno (TM) 810', vulkanVersion: '1.1'),
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
  group('ramRefusalReason', () {
    test('allows a small model that fits the budget', () {
      expect(
        ramRefusalReason(
          modelName: 'Llama 3.2 1B',
          fileBytes: 810 * 1000 * 1000,
          capabilities: _a36Capabilities(),
        ),
        isNull,
      );
    });

    test('refuses a model larger than the safe budget with a clear message',
        () {
      final reason = ramRefusalReason(
        modelName: 'Llama 3.1 8B',
        fileBytes: 3900 * 1000 * 1000,
        capabilities: _a36Capabilities(),
      );

      expect(reason, isNotNull);
      expect(reason, contains('Llama 3.1 8B'));
      expect(reason, contains('3.9 GB'));
      expect(reason, contains('crash'));
    });

    test('a file exactly at the budget is allowed', () {
      final capabilities = _a36Capabilities();
      expect(
        ramRefusalReason(
          modelName: 'Edge',
          fileBytes: capabilities.conservativeModelBudgetBytes,
          capabilities: capabilities,
        ),
        isNull,
      );
    });
  });

  group('engineAcceleratorLabel', () {
    test('names the detected GPU path', () {
      expect(
        engineAcceleratorLabel(_a36Capabilities()),
        contains('Vulkan 1.1'),
      );
    });

    test('is honest when no GPU is detected', () {
      final capabilities = DeviceCapabilities.detect(
        memory: MemoryInfo(totalBytes: 8 * _gb, availableBytes: 4 * _gb),
        storage: StorageInfo(freeBytes: 32 * _gb, totalBytes: 128 * _gb),
        gpu: const GpuProbe(),
        identity: const DeviceIdentity(
          manufacturer: 'Unknown',
          model: 'emu',
          board: 'emu',
          hardware: 'unknown',
          abis: ['arm64-v8a'],
          osVersion: 'Android 16',
        ),
        cpuCores: 8,
      );

      expect(engineAcceleratorLabel(capabilities), contains('CPU'));
    });
  });
}
