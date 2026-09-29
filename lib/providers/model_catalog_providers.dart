import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/model_catalog_repository.dart';
import '../models/model_catalog.dart';
import 'device_capability_providers.dart';

final modelCatalogRepositoryProvider = Provider<ModelCatalogRepository>(
  (ref) => const StaticModelCatalogRepository(),
);

final modelCatalogProvider = FutureProvider<List<CatalogModel>>((ref) async {
  return ref.watch(modelCatalogRepositoryProvider).models();
});

final labeledCatalogProvider = FutureProvider<LabeledCatalog>((ref) async {
  final capabilities = await ref.watch(deviceCapabilitiesProvider.future);
  final models = await ref.watch(modelCatalogProvider.future);
  return LabeledCatalog(
    capabilities: capabilities,
    entries: [
      for (final model in models)
        LabeledCatalogModel(model: model, fit: model.fitFor(capabilities)),
    ],
  );
});
