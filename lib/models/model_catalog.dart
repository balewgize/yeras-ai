import 'device_capabilities.dart';

enum ModelFit { recommended, willBeSlow, wontFit }

class CatalogModel {
  const CatalogModel({
    required this.id,
    required this.name,
    required this.parameterCountLabel,
    required this.parameterCountInBillions,
    required this.quantization,
    required this.contextLength,
    required this.sizeBytes,
    required this.description,
    required this.downloadUrl,
  });

  final String id;
  final String name;
  final String parameterCountLabel;
  final double parameterCountInBillions;
  final String quantization;
  final int contextLength;
  final int sizeBytes;
  final String description;
  final String downloadUrl;

  ModelFit fitFor(DeviceCapabilities capabilities) {
    if (sizeBytes > capabilities.conservativeModelBudgetBytes) {
      return ModelFit.wontFit;
    }
    if (parameterCountInBillions <= 2) return ModelFit.recommended;
    return ModelFit.willBeSlow;
  }
}

class LabeledCatalogModel {
  const LabeledCatalogModel({required this.model, required this.fit});

  final CatalogModel model;
  final ModelFit fit;
}

class LabeledCatalog {
  const LabeledCatalog({required this.capabilities, required this.entries});

  final DeviceCapabilities capabilities;
  final List<LabeledCatalogModel> entries;
}
