import 'package:llamadart/llamadart.dart';

import '../../models/chat.dart';
import '../../models/device_capabilities.dart';
import '../../models/inference.dart';
import '../../models/model_catalog.dart';

class ModelTooLargeException implements Exception {
  const ModelTooLargeException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class InferenceRepository {
  Future<LoadedModelInfo> loadModel({
    required CatalogModel model,
    required String filePath,
    required int fileBytes,
    required DeviceCapabilities capabilities,
  });

  Future<InferenceResult> generate(
    String prompt, {
    required void Function(String token) onToken,
  });

  /// Multi-turn chat: the full [history] is passed to the engine so the
  /// model keeps conversational context. Streams reply tokens via [onToken].
  Future<InferenceResult> chat(
    List<ChatMessage> history, {
    required void Function(String token) onToken,
  });

  void cancelGeneration();

  Future<void> unload();

  Future<void> dispose();
}

class LlamadartInferenceRepository implements InferenceRepository {
  LlamadartInferenceRepository();

  static const int debugContextSize = 2048;
  static const int debugMaxTokens = 128;

  /// Context window for chat. Deliberately small: the KV cache grows with
  /// n_ctx, so this bounds RAM on top of the memory-mapped weights.
  static const int chatContextSize = 2048;

  /// Cap on reply length per turn. Bounds generation time and memory.
  static const int chatMaxTokens = 512;

  LlamaEngine? _engine;
  bool _loaded = false;

  /// Loads [filePath] without pulling the whole file into RAM:
  /// - `useMmap: true` memory-maps the weights so pages stream in on
  ///   demand and the OS can evict them under pressure.
  /// - `useMlock: false` never pins weights in RAM.
  /// - Oversized files are refused up front via [ramRefusalReason].
  static const ModelParams _loadParams = ModelParams(
    contextSize: chatContextSize,
    useMmap: true,
    useMlock: false,
  );

  @override
  Future<LoadedModelInfo> loadModel({
    required CatalogModel model,
    required String filePath,
    required int fileBytes,
    required DeviceCapabilities capabilities,
  }) async {
    final refusal = ramRefusalReason(
      modelName: model.name,
      fileBytes: fileBytes,
      capabilities: capabilities,
    );
    if (refusal != null) throw ModelTooLargeException(refusal);
    await unload();
    final engine = LlamaEngine(LlamaBackend());
    try {
      // _loadParams keeps weights memory-mapped, never fully resident.
      await engine.loadModel(filePath, modelParams: _loadParams);
    } catch (_) {
      await engine.dispose();
      rethrow;
    }
    _engine = engine;
    _loaded = true;
    return LoadedModelInfo(
      modelName: model.name,
      filePath: filePath,
      fileBytes: fileBytes,
      acceleratorLabel: engineAcceleratorLabel(capabilities),
      contextSize: chatContextSize,
    );
  }

  @override
  Future<InferenceResult> generate(
    String prompt, {
    required void Function(String token) onToken,
  }) {
    return _stream(
      [LlamaChatMessage.fromText(role: LlamaChatRole.user, text: prompt)],
      maxTokens: debugMaxTokens,
      onToken: onToken,
    );
  }

  @override
  Future<InferenceResult> chat(
    List<ChatMessage> history, {
    required void Function(String token) onToken,
  }) {
    return _stream(
      [
        for (final message in history)
          LlamaChatMessage.fromText(
            role: switch (message.role) {
              ChatRole.user => LlamaChatRole.user,
              ChatRole.assistant => LlamaChatRole.assistant,
            },
            text: message.text,
          ),
      ],
      maxTokens: chatMaxTokens,
      onToken: onToken,
    );
  }

  Future<InferenceResult> _stream(
    List<LlamaChatMessage> messages, {
    required int maxTokens,
    required void Function(String token) onToken,
  }) async {
    final engine = _engine;
    if (engine == null || !_loaded) {
      throw StateError('No model loaded.');
    }
    final stopwatch = Stopwatch()..start();
    final output = StringBuffer();
    var completionTokens = 0;
    Duration? backendDuration;
    await for (final chunk in engine.create(
      messages,
      params: GenerationParams(maxTokens: maxTokens),
    )) {
      if (chunk.choices.isEmpty) continue;
      final text = chunk.choices.first.delta.content;
      if (text != null && text.isNotEmpty) {
        output.write(text);
        onToken(text);
      }
      final usage = chunk.usage;
      if (usage != null) {
        completionTokens = usage.completionTokens;
        backendDuration = usage.duration;
      }
    }
    stopwatch.stop();
    final elapsed = backendDuration ?? stopwatch.elapsed;
    final seconds = elapsed.inMicroseconds / 1e6;
    return InferenceResult(
      text: output.toString(),
      completionTokens: completionTokens,
      tokensPerSecond: seconds > 0 && completionTokens > 0
          ? completionTokens / seconds
          : null,
    );
  }

  @override
  void cancelGeneration() => _engine?.cancelGeneration();

  @override
  Future<void> unload() async {
    final engine = _engine;
    final wasLoaded = _loaded;
    _engine = null;
    _loaded = false;
    if (engine == null) return;
    if (wasLoaded) {
      try {
        await engine.unloadModel();
      } catch (_) {
        // Best effort; dispose still runs below.
      }
    }
    await engine.dispose();
  }

  @override
  Future<void> dispose() => unload();
}
