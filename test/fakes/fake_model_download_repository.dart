import 'dart:async';

import 'package:yeras_ai/data/repositories/model_download_repository.dart';
import 'package:yeras_ai/models/model_download.dart';

class FakeModelDownloadRepository implements ModelDownloadRepository {
  final Map<String, ModelDownloadState> _current =
      <String, ModelDownloadState>{};
  final Map<String, StreamController<ModelDownloadState>> _streams =
      <String, StreamController<ModelDownloadState>>{};

  final List<String> starts = <String>[];
  final List<String> cancels = <String>[];
  final List<String> deletes = <String>[];

  void emit(String modelId, ModelDownloadState state) {
    _current[modelId] = state;
    _streams[modelId]?.add(state);
  }

  @override
  ModelDownloadState? stateFor(String modelId) => _current[modelId];

  @override
  Stream<ModelDownloadState> statesFor(String modelId) async* {
    yield _current[modelId] ?? const ModelDownloadState.initial();
    yield* _streamFor(modelId).stream;
  }

  @override
  Future<void> start(String modelId) async => starts.add(modelId);

  @override
  void cancel(String modelId) => cancels.add(modelId);

  @override
  Future<void> delete(String modelId) async => deletes.add(modelId);

  @override
  Future<void> dispose() async {
    for (final stream in _streams.values) {
      await stream.close();
    }
    _streams.clear();
    _current.clear();
  }

  StreamController<ModelDownloadState> _streamFor(String modelId) =>
      _streams.putIfAbsent(
        modelId,
        () => StreamController<ModelDownloadState>.broadcast(),
      );
}
