import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/model_download_repository.dart';
import '../models/model_download.dart';
import 'device_capability_providers.dart';
import 'model_catalog_providers.dart';

final modelDownloadRepositoryProvider = Provider<ModelDownloadRepository>((
  ref,
) {
  final repository = LlamadartModelDownloadRepository.platform(
    capabilities: ref.watch(deviceCapabilityRepositoryProvider),
    catalog: ref.watch(modelCatalogRepositoryProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final modelDownloadStateProvider = StreamProvider.family<
  ModelDownloadState,
  String
>((ref, modelId) {
  final repository = ref.watch(modelDownloadRepositoryProvider);
  return repository.statesFor(modelId);
});
