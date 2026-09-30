import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/inference_repository.dart';

final inferenceRepositoryProvider = Provider<InferenceRepository>((ref) {
  final repository = LlamadartInferenceRepository();
  ref.onDispose(repository.dispose);
  return repository;
});
