import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/model_catalog.dart';

abstract class ModelCatalogRepository {
  Future<List<CatalogModel>> models();
}

/// Catalog parsed from the bundled `models_catalog.json` — the single
/// source of truth for the model list. Tests can inject [readCatalogJson]
/// to parse a fixture instead of the app asset.
class StaticModelCatalogRepository implements ModelCatalogRepository {
  const StaticModelCatalogRepository({Future<String> Function()? readCatalogJson})
      : _readCatalogJson = readCatalogJson;

  static const String bundledCatalogAsset = 'lib/data/models_catalog.json';

  final Future<String> Function()? _readCatalogJson;

  @override
  Future<List<CatalogModel>> models() async {
    final loader = _readCatalogJson ?? _loadBundled;
    final decoded = jsonDecode(await loader()) as List<dynamic>;
    return [
      for (final entry in decoded)
        CatalogModel.fromJson(entry as Map<String, dynamic>),
    ];
  }

  static Future<String> _loadBundled() =>
      rootBundle.loadString(bundledCatalogAsset);
}
