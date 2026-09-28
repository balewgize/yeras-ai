import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

import '../../models/device_capabilities.dart';

abstract class DeviceCapabilityRepository {
  Future<MemoryInfo> memory();
  Future<StorageInfo> storage();
  Future<GpuProbe> gpu();
  Future<DeviceIdentity> identity();
}

class PlatformDeviceCapabilityRepository
    implements DeviceCapabilityRepository {
  const PlatformDeviceCapabilityRepository();

  static const MethodChannel _channel = MethodChannel(
    'staylocal/device_capability',
  );

  Future<Map<String, dynamic>> _invoke(String method) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(method);
    if (result == null) {
      throw StateError('No response from platform for "$method".');
    }
    return result;
  }

  @override
  Future<MemoryInfo> memory() async {
    final data = await _invoke('getMemoryInfo');
    return MemoryInfo(
      totalBytes: data['totalBytes'] as int,
      availableBytes: data['availableBytes'] as int,
    );
  }

  @override
  Future<StorageInfo> storage() async {
    final data = await _invoke('getStorageInfo');
    return StorageInfo(
      freeBytes: data['freeBytes'] as int,
      totalBytes: data['totalBytes'] as int,
    );
  }

  @override
  Future<GpuProbe> gpu() async {
    final data = await _invoke('getGpuInfo');
    return GpuProbe(
      renderer: data['renderer'] as String?,
      vulkanVersion: data['vulkanVersion'] as String?,
      metalSupported: data['metalSupported'] as bool? ?? false,
    );
  }

  @override
  Future<DeviceIdentity> identity() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return DeviceIdentity(
        manufacturer: info.manufacturer,
        model: info.model,
        board: info.board,
        hardware: info.hardware,
        abis: info.supportedAbis,
        osVersion: 'Android ${info.version.release}',
      );
    }
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return DeviceIdentity(
        manufacturer: 'Apple',
        model: info.utsname.machine,
        board: info.utsname.machine,
        hardware: 'Apple',
        abis: const ['arm64'],
        osVersion: 'iOS ${info.systemVersion}',
      );
    }
    throw UnsupportedError(
      'Device detection is not implemented for ${Platform.operatingSystem}.',
    );
  }
}
