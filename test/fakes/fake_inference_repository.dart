import 'dart:async';

import 'package:staylocal/data/repositories/inference_repository.dart';
import 'package:staylocal/models/chat.dart';
import 'package:staylocal/models/inference.dart';
import 'package:staylocal/models/model_catalog.dart';
import 'package:staylocal/models/device_capabilities.dart';

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
  final List<String> generatePrompts = <String>[];
  final List<List<ChatMessage>> chatHistories = <List<ChatMessage>>[];

  @override
  Future<LoadedModelInfo> loadModel({
    required CatalogModel model,
    required String filePath,
    required int fileBytes,
    required DeviceCapabilities capabilities,
  }) async {
    loadCalls++;
    lastModelId = model.id;
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
  }) async {
    generatePrompts.add(prompt);
    return _replay(onToken);
  }

  @override
  Future<InferenceResult> chat(
    List<ChatMessage> history, {
    required void Function(String token) onToken,
  }) async {
    chatHistories.add(history);
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
