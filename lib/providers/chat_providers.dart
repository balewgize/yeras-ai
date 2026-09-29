import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/inference_repository.dart';
import '../models/chat.dart';
import '../models/inference.dart';
import '../models/model_catalog.dart';
import '../models/model_download.dart';
import 'device_capability_providers.dart';
import 'foreground_generation_providers.dart';
import 'inference_providers.dart';
import 'model_catalog_providers.dart';
import 'model_download_providers.dart';

/// Persisted id of the model the user picked for chat. Null until chosen.
class SelectedModelController extends Notifier<String?> {
  static const String _prefKey = 'selected_model_id';

  @override
  String? build() {
    _loadSaved();
    return null;
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && saved.isNotEmpty) state = saved;
  }

  Future<void> select(String? modelId) async {
    if (state == modelId) return;
    state = modelId;
    final prefs = await SharedPreferences.getInstance();
    if (modelId == null) {
      await prefs.remove(_prefKey);
    } else {
      await prefs.setString(_prefKey, modelId);
    }
  }
}

final selectedModelIdProvider =
    NotifierProvider<SelectedModelController, String?>(
  SelectedModelController.new,
);

/// Models fully downloaded and ready to load, rebuilt live as downloads
/// finish (each download stream is watched; not-ready models are skipped).
final downloadedModelsProvider = Provider<List<CatalogModel>>((ref) {
  final models = ref.watch(modelCatalogProvider).value ?? const [];
  return [
    for (final model in models)
      if (ref.watch(modelDownloadStateProvider(model.id)).value?.stage ==
          DownloadStage.ready)
        model,
  ];
});

/// The model chat will actually use: the user's pick when it is downloaded,
/// otherwise the first downloaded model, otherwise null.
final activeModelProvider = Provider<CatalogModel?>((ref) {
  final downloaded = ref.watch(downloadedModelsProvider);
  if (downloaded.isEmpty) return null;
  final selected = ref.watch(selectedModelIdProvider);
  if (selected != null) {
    for (final model in downloaded) {
      if (model.id == selected) return model;
    }
  }
  return downloaded.first;
});

enum ChatStage { idle, loadingModel, generating }

/// In-memory single conversation (Phase 5). History persistence is Phase 7.
class ChatState {
  const ChatState({
    this.messages = const [],
    this.stage = ChatStage.idle,
    this.loadingModelName,
    this.loadedModelId,
    this.errorMessage,
    this.infoMessage,
    this.contextFull = false,
  });

  final List<ChatMessage> messages;
  final ChatStage stage;
  final String? loadingModelName;
  final String? loadedModelId;
  final String? errorMessage;
  final String? infoMessage;
  final bool contextFull;

  bool get isBusy =>
      stage == ChatStage.loadingModel || stage == ChatStage.generating;

  ChatState copyWith({
    List<ChatMessage>? messages,
    ChatStage? stage,
    String? loadingModelName,
    String? loadedModelId,
    bool clearLoadedModel = false,
    String? errorMessage,
    String? infoMessage,
    bool? contextFull,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      stage: stage ?? this.stage,
      loadingModelName: loadingModelName,
      loadedModelId:
          clearLoadedModel ? null : (loadedModelId ?? this.loadedModelId),
      errorMessage: errorMessage,
      infoMessage: infoMessage,
      contextFull: contextFull ?? false,
    );
  }
}

/// True when the active downloaded model is resident in memory.
final isModelLoadedProvider = Provider<bool>((ref) {
  final active = ref.watch(activeModelProvider);
  if (active == null) return false;
  return ref.watch(
    chatControllerProvider.select((chat) => chat.loadedModelId == active.id),
  );
});

class ChatController extends Notifier<ChatState> {
  int _generation = 0;

  @override
  ChatState build() => const ChatState();

  /// Android foreground service keeps the process (and generation) alive
  /// while the app is backgrounded. Held exactly while busy, never longer.
  void _beginBusyForeground() {
    unawaited(ref.read(foregroundGenerationProvider).start());
  }

  void _endBusyForeground() {
    unawaited(ref.read(foregroundGenerationProvider).stop());
  }

  Future<void> send(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || state.isBusy) return;

    final model = ref.read(activeModelProvider);
    if (model == null) {
      state = state.copyWith(
        errorMessage: 'Download a model first, then ask away.',
      );
      return;
    }
    // Hard gate: the user must intentionally load the model via the
    // top-bar action before chatting. No lazy load on send.
    if (state.loadedModelId != model.id) {
      state = state.copyWith(
        errorMessage:
            'Load ${model.name} from the top bar to start chatting.',
      );
      return;
    }

    final history = [
      ...state.messages,
      ChatMessage(role: ChatRole.user, text: prompt),
    ];
    state = state.copyWith(
      messages: history,
      errorMessage: null,
      infoMessage: null,
    );
    await _generate(model, history);
  }

  Future<void> retry() async {
    if (state.isBusy || state.messages.isEmpty) return;
    final model = ref.read(activeModelProvider);
    if (model == null) return;
    if (state.loadedModelId != model.id) {
      state = state.copyWith(
        errorMessage:
            'Load ${model.name} from the top bar to start chatting.',
      );
      return;
    }
    // Drop a trailing empty assistant bubble left by the failed attempt.
    final history = [...state.messages];
    if (history.isNotEmpty &&
        history.last.role == ChatRole.assistant &&
        history.last.text.isEmpty) {
      history.removeLast();
    }
    state = state.copyWith(messages: history, errorMessage: null);
    await _generate(model, history);
  }

  /// Intentionally load the active model into memory (top-bar action).
  Future<void> loadActiveModel() async {
    if (state.isBusy) return;
    final model = ref.read(activeModelProvider);
    if (model == null) {
      state = state.copyWith(
        errorMessage: 'Download a model first, then ask away.',
      );
      return;
    }
    if (state.loadedModelId == model.id) {
      state = state.copyWith(infoMessage: '${model.name} already loaded.');
      return;
    }
    final turn = ++_generation;
    bool isStale() => turn != _generation;
    _beginBusyForeground();
    state = state.copyWith(
      stage: ChatStage.loadingModel,
      loadingModelName: model.name,
      errorMessage: null,
      infoMessage: null,
    );
    try {
      await _ensureLoaded(model);
      if (isStale()) return;
      state = state.copyWith(
        stage: ChatStage.idle,
        loadedModelId: model.id,
        loadingModelName: null,
        infoMessage: '${model.name} loaded · ready offline.',
      );
    } on ModelTooLargeException catch (error) {
      if (isStale()) return;
      state = state.copyWith(
        stage: ChatStage.idle,
        loadingModelName: null,
        errorMessage: 'Load failed: ${error.message}',
      );
    } catch (error) {
      if (isStale()) return;
      state = state.copyWith(
        stage: ChatStage.idle,
        loadingModelName: null,
        errorMessage: 'Load failed: $error',
      );
    } finally {
      _endBusyForeground();
    }
  }

  /// Unload the resident model and free memory (top-bar action).
  Future<void> unloadModel() async {
    if (state.isBusy) {
      state = state.copyWith(infoMessage: 'Stop generation first.');
      return;
    }
    final loadedId = state.loadedModelId;
    if (loadedId == null) {
      state = state.copyWith(infoMessage: 'Nothing loaded.');
      return;
    }
    final downloaded = ref.read(downloadedModelsProvider);
    final loadedName = downloaded
        .where((model) => model.id == loadedId)
        .map((model) => model.name)
        .firstOrNull;
    await ref.read(inferenceRepositoryProvider).unload();
    if (state.isBusy) return;
    state = state.copyWith(
      clearLoadedModel: true,
      errorMessage: null,
      infoMessage: '${loadedName ?? 'Model'} unloaded · memory freed.',
    );
  }

  Future<void> _ensureLoaded(CatalogModel model) async {
    final download = ref.read(modelDownloadRepositoryProvider).stateFor(
      model.id,
    );
    final filePath = download?.filePath;
    if (download?.stage != DownloadStage.ready || filePath == null) {
      throw StateError('${model.name} is not downloaded.');
    }
    final fileBytes = download!.receivedBytes > 0
        ? download.receivedBytes
        : model.sizeBytes;
    final capabilities = await ref.read(deviceCapabilitiesProvider.future);
    await ref
        .read(inferenceRepositoryProvider)
        .loadModel(
          model: model,
          filePath: filePath,
          fileBytes: fileBytes,
          capabilities: capabilities,
        );
  }

  Future<void> _generate(CatalogModel model, List<ChatMessage> history) async {
    final turn = ++_generation;
    final repository = ref.read(inferenceRepositoryProvider);
    bool isStale() => turn != _generation;
    _beginBusyForeground();

    try {
      // Defensive: send()/retry() hard-gate on loadedModelId, so this is
      // normally a no-op. Kept so _generate never streams on no model.
      if (state.loadedModelId != model.id) {
        await _ensureLoaded(model);
        state = state.copyWith(loadedModelId: model.id);
      }

      state = state.copyWith(
        stage: ChatStage.generating,
        messages: [
          ...history,
          const ChatMessage(role: ChatRole.assistant, text: ''),
        ],
      );
      final result = await repository.chat(
        history,
        onToken: (token) {
          // Tokens arriving after Stop are dropped.
          if (state.stage != ChatStage.generating) return;
          final messages = [...state.messages];
          if (messages.isNotEmpty &&
              messages.last.role == ChatRole.assistant) {
            messages[messages.length - 1] = messages.last.appending(token);
            state = state.copyWith(
              stage: ChatStage.generating,
              messages: messages,
            );
          }
        },
      );
      final messages = [...state.messages];
      if (!isStale()) {
        if (messages.isNotEmpty &&
            messages.last.role == ChatRole.assistant) {
          messages[messages.length - 1] =
              messages.last.withRate(result.tokensPerSecond);
        }
        state = state.copyWith(stage: ChatStage.idle, messages: messages);
      }
    } on ModelTooLargeException catch (error) {
      if (isStale()) return;
      state = state.copyWith(
        stage: ChatStage.idle,
        errorMessage: error.message,
      );
    } catch (error) {
      if (isStale()) return;
      if (isContextFullError(error)) {
        state = state.copyWith(
          stage: ChatStage.idle,
          contextFull: true,
          errorMessage:
              'This conversation outgrew the model context window. '
              'Start a new chat to continue.',
        );
      } else {
        state = state.copyWith(
          stage: ChatStage.idle,
          errorMessage: '$error',
        );
      }
    } finally {
      _endBusyForeground();
    }
  }

  void stop() {
    if (state.stage != ChatStage.generating) return;
    _generation++;
    ref.read(inferenceRepositoryProvider).cancelGeneration();
    // Stop the service now rather than waiting for the cancelled stream
    // to unwind; the finally in _generate is deduped by the running flag.
    _endBusyForeground();
    state = state.copyWith(stage: ChatStage.idle);
  }

  void newChat() {
    _generation++;
    if (state.isBusy) {
      ref.read(inferenceRepositoryProvider).cancelGeneration();
      _endBusyForeground();
    }
    state = state.copyWith(
      messages: const [],
      stage: ChatStage.idle,
      errorMessage: null,
      infoMessage: null,
    );
  }
}

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
