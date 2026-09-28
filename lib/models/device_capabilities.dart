class MemoryInfo {
  const MemoryInfo({required this.totalBytes, required this.availableBytes});

  final int totalBytes;
  final int availableBytes;
}

class StorageInfo {
  const StorageInfo({required this.freeBytes, required this.totalBytes});

  final int freeBytes;
  final int totalBytes;
}

class GpuProbe {
  const GpuProbe({
    this.renderer,
    this.vulkanVersion,
    this.metalSupported = false,
  });

  final String? renderer;
  final String? vulkanVersion;
  final bool metalSupported;
}

class DeviceIdentity {
  const DeviceIdentity({
    required this.manufacturer,
    required this.model,
    required this.board,
    required this.hardware,
    required this.abis,
    required this.osVersion,
  });

  final String manufacturer;
  final String model;
  final String board;
  final String hardware;
  final List<String> abis;
  final String osVersion;

  String? get chipsetVendor {
    final source = '$hardware $board'.toLowerCase();
    if (source.contains('qcom') || source.contains('qualcomm')) {
      return 'Qualcomm';
    }
    if (source.contains('exynos') || source.contains('universal')) {
      return 'Samsung';
    }
    if (source.contains('mediatek') || source.contains('mt6')) {
      return 'MediaTek';
    }
    if (source.contains('tensor')) {
      return 'Google';
    }
    if (hardware.toLowerCase().contains('apple') ||
        manufacturer.toLowerCase().contains('apple')) {
      return 'Apple';
    }
    return null;
  }
}

enum AcceleratorType { cpu, gpu, npu }

enum AcceleratorStatus { usedByEngine, pendingVerification, notUsed }

class AcceleratorInfo {
  const AcceleratorInfo({
    required this.type,
    required this.name,
    required this.status,
    this.detail,
  });

  final AcceleratorType type;
  final String name;
  final AcceleratorStatus status;
  final String? detail;
}

class DeviceCapabilities {
  const DeviceCapabilities({
    required this.memory,
    required this.storage,
    required this.identity,
    required this.accelerators,
    required this.cpuCores,
  });

  final MemoryInfo memory;
  final StorageInfo storage;
  final DeviceIdentity identity;
  final List<AcceleratorInfo> accelerators;
  final int cpuCores;

  factory DeviceCapabilities.detect({
    required MemoryInfo memory,
    required StorageInfo storage,
    required GpuProbe gpu,
    required DeviceIdentity identity,
    required int cpuCores,
  }) {
    final accelerators = <AcceleratorInfo>[
      AcceleratorInfo(
        type: AcceleratorType.cpu,
        name: 'CPU',
        status: AcceleratorStatus.usedByEngine,
        detail: '$cpuCores cores · ${identity.abis.join(', ')}',
      ),
      if (gpu.renderer != null || gpu.metalSupported)
        AcceleratorInfo(
          type: AcceleratorType.gpu,
          name: gpu.renderer ?? 'GPU',
          status: AcceleratorStatus.pendingVerification,
          detail: _gpuDetail(gpu),
        ),
      if (_npuName(identity) != null)
        AcceleratorInfo(
          type: AcceleratorType.npu,
          name: _npuName(identity)!,
          status: AcceleratorStatus.notUsed,
        ),
    ];
    return DeviceCapabilities(
      memory: memory,
      storage: storage,
      identity: identity,
      accelerators: accelerators,
      cpuCores: cpuCores,
    );
  }

  static String? _gpuDetail(GpuProbe gpu) {
    if (gpu.vulkanVersion != null) return 'Vulkan ${gpu.vulkanVersion}';
    if (gpu.metalSupported) return 'Metal';
    return null;
  }

  static String? _npuName(DeviceIdentity identity) {
    return switch (identity.chipsetVendor) {
      'Qualcomm' => 'Hexagon NPU',
      'Apple' => 'Neural Engine',
      _ => null,
    };
  }

  int get conservativeModelBudgetBytes {
    final halfOfTotal = memory.totalBytes ~/ 2;
    final shareOfAvailable = memory.availableBytes * 7 ~/ 10;
    return halfOfTotal < shareOfAvailable
        ? halfOfTotal
        : shareOfAvailable;
  }
}
