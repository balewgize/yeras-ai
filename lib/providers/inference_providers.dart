import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/inference_repository.dart';
import '../models/inference.dart';
import '../models/model_download.dart';
import '../providers/device_capability_providers.dart';
import '../providers/model_catalog_providers.dart';
import 'model_download_providers.dart';

const String debugPrompt =
    'Reply with the exact words "on-device OK", then in one short sentence '
    'say why running offline is private.';

final inferenceRepositoryProvider = Provider<InferenceRepository>((ref) {
  final repository = LlamadartInferenceRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

class InferenceDebugController extends Notifier<InferenceDebugState> {
  InferenceDebugController(this.modelId);

  final String modelId;

  @override
  InferenceDebugState build() {
    // Capture the repository before registering the callback: ref.read
    // inside onDispose is illegal and crashes at teardown.
    final repository = ref.watch(inferenceRepositoryProvider);
    ref.onDispose(() {
      unawaited(repository.unload());
    });
    return const InferenceDebugState();
  }

  Future<void> run() async {
    if (state.stage == InferenceStage.loading ||
        state.stage == InferenceStage.generating) {
      return;
    }
    state = const InferenceDebugState(stage: InferenceStage.loading);
    try {
      final models = await ref.read(modelCatalogRepositoryProvider).models();
      final model = models.firstWhere((entry) => entry.id == modelId);
      final download = ref.read(modelDownloadRepositoryProvider).stateFor(
        modelId,
      );
      final filePath = download?.filePath;
      if (download?.stage != DownloadStage.ready || filePath == null) {
        throw StateError('${model.name} is not downloaded.');
      }
      final fileBytes = download!.receivedBytes > 0
          ? download.receivedBytes
          : model.sizeBytes;
      final capabilities = await ref.read(deviceCapabilitiesProvider.future);
      final info = await ref
          .read(inferenceRepositoryProvider)
          .loadModel(
            model: model,
            filePath: filePath,
            fileBytes: fileBytes,
            capabilities: capabilities,
          );
      state = state.copyWith(stage: InferenceStage.generating, model: info);
      final result = await ref
          .read(inferenceRepositoryProvider)
          .generate(
            debugPrompt,
            onToken: (token) =>
                state = state.copyWith(output: '${state.output}$token'),
          );
      state = state.copyWith(
        stage: InferenceStage.done,
        tokensPerSecond: result.tokensPerSecond,
        completionTokens: result.completionTokens,
      );
    } catch (error) {
      state = state.copyWith(
        stage: InferenceStage.error,
        errorMessage: '$error',
      );
    }
  }

  void stop() => ref.read(inferenceRepositoryProvider).cancelGeneration();
}

final inferenceDebugControllerProvider =
    NotifierProvider.autoDispose.family<
      InferenceDebugController,
      InferenceDebugState,
      String
    >(InferenceDebugController.new);
