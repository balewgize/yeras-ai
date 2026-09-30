import 'dart:async';

import 'package:yeras_ai/data/repositories/inference_repository.dart';
import 'package:yeras_ai/models/chat.dart';
import 'package:yeras_ai/models/inference.dart';
import 'package:yeras_ai/models/model_catalog.dart';
import 'package:yeras_ai/models/device_capabilities.dart';

/// Scriptable fake for chat + debug inference tests.
class FakeInferenceRepository implements InferenceRepository {
  LoadedModelInfo? loadedInfo;
  Object? loadError;
  Object? chatError;
  Completer<void>? chatGate;
  List<String> tokenScript = const <String>[];
  InferenceResult? scriptResult;

  int loadCalls = 0;
  int stopCalls = 0;
  int unloadCalls = 0;
  String? lastModelId;
  int? lastContextSize;
  double? lastTemperature;
  final List<String> generatePrompts = <String>[];
  final List<List<ChatMessage>> chatHistories = <List<ChatMessage>>[];

  @override
  Future<LoadedModelInfo> loadModel({
    required CatalogModel model,
    required String filePath,
    required int fileBytes,
    required DeviceCapabilities capabilities,
    int? contextSize,
  }) async {
    loadCalls++;
    lastModelId = model.id;
    lastContextSize = contextSize;
    if (loadError != null) throw loadError!;
    return loadedInfo ??
        LoadedModelInfo(
          modelName: model.name,
          filePath: filePath,
          fileBytes: fileBytes,
          acceleratorLabel: 'Fake accelerator',
          contextSize: 2048,
        );
  }

  InferenceResult _replay(void Function(String token) onToken) {
    for (final token in tokenScript) {
      onToken(token);
    }
    return scriptResult ??
        InferenceResult(
          text: tokenScript.join(),
          completionTokens: tokenScript.length,
        );
  }

  @override
  Future<InferenceResult> generate(
    String prompt, {
    required void Function(String token) onToken,
    double? temperature,
  }) async {
    generatePrompts.add(prompt);
    lastTemperature = temperature;
    return _replay(onToken);
  }

  @override
  Future<InferenceResult> chat(
    List<ChatMessage> history, {
    required void Function(String token) onToken,
    double? temperature,
  }) async {
    chatHistories.add(history);
    lastTemperature = temperature;
    final gate = chatGate;
    if (gate != null) await gate.future;
    if (chatError != null) throw chatError!;
    return _replay(onToken);
  }

  @override
  void cancelGeneration() => stopCalls++;

  @override
  Future<void> unload() async => unloadCalls++;

  @override
  Future<void> dispose() async {}
}
