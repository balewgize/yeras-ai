import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/device_capability_repository.dart';
import '../models/device_capabilities.dart';

final deviceCapabilityRepositoryProvider = Provider<DeviceCapabilityRepository>(
  (ref) => const PlatformDeviceCapabilityRepository(),
);

final deviceCapabilitiesProvider = FutureProvider<DeviceCapabilities>((ref) async {
  final repository = ref.watch(deviceCapabilityRepositoryProvider);
  final memory = await repository.memory();
  final storage = await repository.storage();
  final gpu = await repository.gpu();
  final identity = await repository.identity();
  return DeviceCapabilities.detect(
    memory: memory,
    storage: storage,
    gpu: gpu,
    identity: identity,
    cpuCores: Platform.numberOfProcessors,
  );
});
