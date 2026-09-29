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
    required this.minRamGb,
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

  /// Minimum device RAM in GB for this model to make sense.
  final int minRamGb;
  final String description;
  final String downloadUrl;

  /// Parses one entry of `models_catalog.json` (`size_mb` is decimal MB).
  factory CatalogModel.fromJson(Map<String, dynamic> json) {
    return CatalogModel(
      id: json['id'] as String,
      name: json['name'] as String,
      parameterCountLabel: json['parameter_count_label'] as String,
      parameterCountInBillions:
          (json['parameter_count_in_billions'] as num).toDouble(),
      quantization: json['quantization'] as String,
      contextLength: (json['context_length'] as num).toInt(),
      sizeBytes: (json['size_mb'] as num).toInt() * 1000 * 1000,
      minRamGb: (json['min_ram_gb'] as num).toInt(),
      description: json['description'] as String,
      downloadUrl: json['download_url'] as String,
    );
  }

  ModelFit fitFor(DeviceCapabilities capabilities) {
    if (sizeBytes > capabilities.conservativeModelBudgetBytes ||
        capabilities.memory.totalBytes < minRamGb * 1000 * 1000 * 1000) {
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
