import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/foreground_generation.dart';

final foregroundGenerationProvider = Provider<ForegroundGenerationService>((
  ref,
) {
  final service = ForegroundGenerationService();
  ref.onDispose(service.stop);
  return service;
});
