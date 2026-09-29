import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/inference_repository.dart';
import '../models/chat.dart';
import '../models/conversation.dart';
import '../models/inference.dart';
import '../models/model_catalog.dart';
import '../models/model_download.dart';
import 'chat_history_providers.dart';
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

/// Active conversation state. Messages also persist to Phase 7 storage as
/// they stream, so history survives backgrounding and force-closes.
class ChatState {
  const ChatState({
    this.messages = const [],
    this.stage = ChatStage.idle,
    this.loadingModelName,
    this.loadedModelId,
    this.activeConversationId,
    this.errorMessage,
    this.infoMessage,
    this.contextFull = false,
    this.wasInterrupted = false,
  });

  final List<ChatMessage> messages;
  final ChatStage stage;
  final String? loadingModelName;
  final String? loadedModelId;

  /// Conversation these messages belong to. Null until the first send.
  final String? activeConversationId;
  final String? errorMessage;
  final String? infoMessage;
  final bool contextFull;

  /// True when the last reply never finished because the app died
  /// mid-generation; cleared by the next send.
  final bool wasInterrupted;

  bool get isBusy =>
      stage == ChatStage.loadingModel || stage == ChatStage.generating;

  ChatState copyWith({
    List<ChatMessage>? messages,
    ChatStage? stage,
    String? loadingModelName,
    String? loadedModelId,
    String? activeConversationId,
    bool clearActiveConversation = false,
    bool clearLoadedModel = false,
    String? errorMessage,
    String? infoMessage,
    bool? contextFull,
    bool? wasInterrupted,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      stage: stage ?? this.stage,
      loadingModelName: loadingModelName,
      loadedModelId:
          clearLoadedModel ? null : (loadedModelId ?? this.loadedModelId),
      activeConversationId: clearActiveConversation
          ? null
          : (activeConversationId ?? this.activeConversationId),
      errorMessage: errorMessage,
      infoMessage: infoMessage,
      contextFull: contextFull ?? false,
      wasInterrupted: wasInterrupted ?? false,
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

  /// Working copy of the active conversation. Every persist writes this
  /// (with the current messages) through the conversations controller.
  Conversation? _active;

  /// Throttled stream persistence: rewrite storage at most every
  /// [_streamFlushInterval] or [_streamFlushTokens] tokens.
  DateTime? _lastStreamFlush;
  int _tokensSinceFlush = 0;

  static const Duration _streamFlushInterval = Duration(milliseconds: 400);
  static const int _streamFlushTokens = 8;

  static const String _lastConversationPrefKey =
      'last_active_conversation_id';
  static int _conversationSequence = 0;

  @override
  ChatState build() {
    _restoreLastActiveConversation();
    return const ChatState();
  }

  /// Android foreground service keeps the process (and generation) alive
  /// while the app is backgrounded. Held exactly while busy, never longer.
  void _beginBusyForeground() {
    unawaited(ref.read(foregroundGenerationProvider).start());
  }

  void _endBusyForeground() {
    unawaited(ref.read(foregroundGenerationProvider).stop());
  }

  /// Reopens the conversation active at last shutdown (or the one killed
  /// mid-reply), so force-close is a resume, not a reset.
  Future<void> _restoreLastActiveConversation() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_lastConversationPrefKey);
    if (id == null || id.isEmpty) return;
    final conversations =
        await ref.read(chatHistoryRepositoryProvider).loadConversations();
    Conversation? match;
    for (final conversation in conversations) {
      if (conversation.id == id) match = conversation;
    }
    if (match == null) return;
    _active = match;
    state = ChatState(
      messages: match.messages,
      activeConversationId: match.id,
      wasInterrupted: match.interrupted,
    );
  }

  Future<void> _saveLastActiveConversationId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastConversationPrefKey, id);
  }

  Future<void> _clearLastActiveConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastConversationPrefKey);
  }

  String _newConversationId() {
    _conversationSequence++;
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '-$_conversationSequence';
  }

  /// Writes the active conversation (current messages + status flags) to
  /// storage; the drawer list refreshes from the same upsert.
  Future<void> _persistActiveConversation({
    required bool generating,
    required bool interrupted,
  }) async {
    final active = _active;
    if (active == null) return;
    _active = active.copyWith(
      messages: state.messages,
      updatedAt: DateTime.now(),
      generating: generating,
      interrupted: interrupted,
    );
    await ref.read(conversationsProvider.notifier).upsert(_active!);
  }

  /// Writes out a conversation detached by newChat()/openConversation()
  /// while its reply was still streaming: an explicit abandon, so the
  /// partial reply persists cleanly (generating cleared, no interrupted
  /// flag) instead of looking like a crash.
  Future<void> _finalizeDetachedConversation(
    Conversation active,
    List<ChatMessage> messages,
  ) async {
    await ref.read(conversationsProvider.notifier).upsert(
          active.copyWith(
            messages: messages,
            updatedAt: DateTime.now(),
            generating: false,
            interrupted: false,
          ),
        );
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

    // Drop a trailing empty assistant bubble left by an interrupted reply.
    final prior = [...state.messages];
    if (prior.isNotEmpty &&
        prior.last.role == ChatRole.assistant &&
        prior.last.text.isEmpty) {
      prior.removeLast();
    }
    final now = DateTime.now();
    final base = _active ??
        Conversation(
          id: _newConversationId(),
          modelId: model.id,
          createdAt: now,
          updatedAt: now,
        );
    _active = base.copyWith(
      messages: [...prior, ChatMessage(role: ChatRole.user, text: prompt)],
      updatedAt: now,
      generating: false,
      interrupted: false,
    );
    final history = _active!.messages;
    state = state.copyWith(
      messages: history,
      activeConversationId: _active!.id,
      errorMessage: null,
      infoMessage: null,
      wasInterrupted: false,
    );
    await ref.read(conversationsProvider.notifier).upsert(_active!);
    unawaited(_saveLastActiveConversationId(_active!.id));
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
    state = state.copyWith(
      messages: history,
      errorMessage: null,
      wasInterrupted: false,
    );
    await _generate(model, history);
  }

  /// Resume the conversation with [id] in the drawer. Stays on-model:
  /// the resident model is kept, its gate still applies.
  Future<void> openConversation(String id) async {
    Conversation? match;
    for (final conversation in ref.read(conversationsProvider)) {
      if (conversation.id == id) match = conversation;
    }
    if (match == null || match.id == state.activeConversationId) return;
    // Switching mid-generation finalizes the abandoned reply cleanly.
    final detached = state.isBusy ? _active : null;
    final detachedMessages = state.messages;
    if (state.isBusy) stop();
    _active = match;
    if (detached != null &&
        detached.generating &&
        detachedMessages.isNotEmpty) {
      unawaited(_finalizeDetachedConversation(detached, detachedMessages));
    }
    state = ChatState(
      messages: match.messages,
      loadedModelId: state.loadedModelId,
      activeConversationId: match.id,
      wasInterrupted: match.interrupted,
    );
    unawaited(_saveLastActiveConversationId(match.id));
  }

  Future<void> renameConversation(String id, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    await ref
        .read(conversationsProvider.notifier)
        .renameConversation(id, trimmed);
    // Keep the working copy in sync so the next send doesn't silently
    // revert the rename in storage.
    if (_active?.id == id) _active = _active!.copyWith(title: trimmed);
  }

  /// Delete must actually work per-conversation: it removes exactly [id]
  /// from storage, and clears the screen only when it was the active one.
  Future<void> deleteConversation(String id) async {
    await ref.read(conversationsProvider.notifier).deleteConversation(id);
    if (_active?.id != id) return;
    _generation++;
    if (state.isBusy) {
      ref.read(inferenceRepositoryProvider).cancelGeneration();
      _endBusyForeground();
    }
    _active = null;
    unawaited(_clearLastActiveConversationId());
    state = state.copyWith(
      messages: const [],
      stage: ChatStage.idle,
      errorMessage: null,
      infoMessage: null,
      clearActiveConversation: true,
      wasInterrupted: false,
    );
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
    final conversationId = state.activeConversationId;

    try {
      // Defensive: send()/retry() hard-gate on loadedModelId, so this is
      // normally a no-op. Kept so _generate never streams on no model.
      if (state.loadedModelId != model.id) {
        await _ensureLoaded(model);
        state = state.copyWith(loadedModelId: model.id);
      }

      _tokensSinceFlush = 0;
      _lastStreamFlush = DateTime.now();
      state = state.copyWith(
        stage: ChatStage.generating,
        messages: [
          ...history,
          const ChatMessage(role: ChatRole.assistant, text: ''),
        ],
      );
      // Mark streaming in storage up front so a process death before the
      // first token still restores as an interrupted reply.
      await _persistActiveConversation(generating: true, interrupted: false);

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
            _tokensSinceFlush++;
            final now = DateTime.now();
            if (_tokensSinceFlush >= _streamFlushTokens ||
                now.difference(_lastStreamFlush!) >= _streamFlushInterval) {
              _tokensSinceFlush = 0;
              _lastStreamFlush = now;
              // Streamed text survives a force-close mid-reply; throttled
              // so storage isn't rewritten on every token.
              unawaited(
                _persistActiveConversation(
                  generating: true,
                  interrupted: false,
                ),
              );
            }
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
      if (!isStale()) {
        state = state.copyWith(
          stage: ChatStage.idle,
          errorMessage: error.message,
        );
      }
    } catch (error) {
      if (!isStale()) {
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
      }
    } finally {
      _endBusyForeground();
    }
    // Persist the finished/failed reply — but only if this generation
    // still owns the active conversation (a switch/newChat/delete since
    // detaches it and finalizes separately).
    if (_active?.id == conversationId) {
      await _persistActiveConversation(generating: false, interrupted: false);
    }
  }

  void stop() {
    if (state.stage != ChatStage.generating) return;
    _generation++;
    ref.read(inferenceRepositoryProvider).cancelGeneration();
    // Stop the service now rather than waiting for the cancelled stream
    // to unwind; the finally in _generate is deduped by the running flag.
    _endBusyForeground();
    // The stopped-early reply persists when the cancelled stream unwinds.
    state = state.copyWith(stage: ChatStage.idle);
  }

  void newChat() {
    _generation++;
    final detached = _active;
    final detachedMessages = state.messages;
    if (state.isBusy) {
      ref.read(inferenceRepositoryProvider).cancelGeneration();
      _endBusyForeground();
    }
    _active = null;
    if (detached != null &&
        detached.generating &&
        detachedMessages.isNotEmpty) {
      unawaited(_finalizeDetachedConversation(detached, detachedMessages));
    }
    unawaited(_clearLastActiveConversationId());
    state = state.copyWith(
      messages: const [],
      stage: ChatStage.idle,
      errorMessage: null,
      infoMessage: null,
      clearActiveConversation: true,
      wasInterrupted: false,
    );
  }
}

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
