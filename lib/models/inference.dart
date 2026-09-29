import 'device_capabilities.dart';
import '../utils/format.dart';

enum InferenceStage { idle, loading, generating, done, error }

class LoadedModelInfo {
  const LoadedModelInfo({
    required this.modelName,
    required this.filePath,
    required this.fileBytes,
    required this.acceleratorLabel,
    required this.contextSize,
  });

  final String modelName;
  final String filePath;
  final int fileBytes;
  final String acceleratorLabel;
  final int contextSize;
}

class InferenceResult {
  const InferenceResult({
    required this.text,
    required this.completionTokens,
    this.tokensPerSecond,
  });

  final String text;
  final int completionTokens;
  final double? tokensPerSecond;
}

class InferenceDebugState {
  const InferenceDebugState({
    this.stage = InferenceStage.idle,
    this.output = '',
    this.errorMessage,
    this.model,
    this.tokensPerSecond,
    this.completionTokens,
  });

  final InferenceStage stage;
  final String output;
  final String? errorMessage;
  final LoadedModelInfo? model;
  final double? tokensPerSecond;
  final int? completionTokens;

  InferenceDebugState copyWith({
    InferenceStage? stage,
    String? output,
    String? errorMessage,
    LoadedModelInfo? model,
    double? tokensPerSecond,
    int? completionTokens,
  }) {
    return InferenceDebugState(
      stage: stage ?? this.stage,
      output: output ?? this.output,
      errorMessage: errorMessage,
      model: model ?? this.model,
      tokensPerSecond: tokensPerSecond,
      completionTokens: completionTokens,
    );
  }
}

String? ramRefusalReason({
  required String modelName,
  required int fileBytes,
  required DeviceCapabilities capabilities,
}) {
  final budget = capabilities.conservativeModelBudgetBytes;
  if (fileBytes <= budget) return null;
  return '$modelName needs about ${formatBytes(fileBytes)} to load, but '
      'only about ${formatBytes(budget)} is safely usable for models on '
      'this device. Loading it anyway would likely crash the app.';
}
String engineAcceleratorLabel(DeviceCapabilities capabilities) {
  for (final accelerator in capabilities.accelerators) {
    if (accelerator.type == AcceleratorType.gpu) {
      final detail = accelerator.detail;
      return detail == null
          ? 'GPU (${accelerator.name}) · full offload'
          : 'GPU (${accelerator.name} · $detail) · full offload';
    }
  }
  return 'CPU · no GPU detected';
}

/// True when [error] looks like the conversation outgrew the model's
/// context window (KV cache full), as opposed to a load/generation bug.
/// Callers surface a clear "context full — start a new chat" state instead
/// of stalling or cutting off silently.
bool isContextFullError(Object error) {
  final message = '$error'.toLowerCase();
  return message.contains('n_ctx') ||
      message.contains('context') && message.contains('full') ||
      message.contains('context') && message.contains('exceed') ||
      message.contains('kv cache') ||
      message.contains('kv_cache') ||
      message.contains('no kv slot') ||
      message.contains('prompt too long');
}
