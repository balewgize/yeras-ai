import 'dart:async';
import 'dart:io';

import 'package:llamadart/llamadart.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/model_catalog.dart';
import '../../models/model_download.dart';
import '../../utils/download_errors.dart';
import '../../utils/download_speed.dart';
import '../../utils/format.dart';
import 'device_capability_repository.dart';
import 'model_catalog_repository.dart';

const int _storageHeadroomBytes = 64 * 1024 * 1024;

abstract class ModelDownloadRepository {
  ModelDownloadState? stateFor(String modelId);

  Stream<ModelDownloadState> statesFor(String modelId);

  Future<void> start(String modelId);

  void cancel(String modelId);

  Future<void> delete(String modelId);

  Future<void> dispose();
}

class LlamadartModelDownloadRepository implements ModelDownloadRepository {
  LlamadartModelDownloadRepository({
    required DeviceCapabilityRepository capabilities,
    required ModelCatalogRepository catalog,
    required Future<String> Function() resolveCacheDirectory,
  }) : _capabilities = capabilities,
       _catalog = catalog,
       _resolveCacheDirectory = resolveCacheDirectory;

  LlamadartModelDownloadRepository.platform({
    required DeviceCapabilityRepository capabilities,
    required ModelCatalogRepository catalog,
  }) : this(
         capabilities: capabilities,
         catalog: catalog,
         resolveCacheDirectory: () async =>
             p.join((await getApplicationCacheDirectory()).path, 'models'),
       );

  final DeviceCapabilityRepository _capabilities;
  final ModelCatalogRepository _catalog;
  final Future<String> Function() _resolveCacheDirectory;

  final Map<String, CatalogModel> _models = {};
  final Map<String, ModelDownloadState> _states = {};
  final Map<String, StreamController<ModelDownloadState>> _streams = {};
  final Map<String, ModelDownloadController> _controllers = {};
  final Map<String, StreamSubscription<ModelDownloadTaskSnapshot>>
  _subscriptions = {};
  final Set<String> _active = {};
  final Map<String, DownloadSpeedTracker> _speedTrackers = {};
  final Map<String, int> _resumeFloors = {};

  DefaultModelDownloadManager? _manager;
  String? _cacheRoot;

  @override
  ModelDownloadState? stateFor(String modelId) => _states[modelId];

  @override
  Stream<ModelDownloadState> statesFor(String modelId) {
    final controller = _streams.putIfAbsent(modelId, () {
      final stream = StreamController<ModelDownloadState>.broadcast();
      stream.onListen = () => unawaited(_refresh(modelId));
      return stream;
    });
    return controller.stream;
  }

  @override
  Future<void> start(String modelId) async {
    if (_active.contains(modelId)) return;
    _speedTrackers.remove(modelId);
    final model = await _modelFor(modelId);
    _emit(
      modelId,
      const ModelDownloadState(stage: DownloadStage.preparing),
    );
    final storage = await _capabilities.storage();
    final requiredBytes = model.sizeBytes + _storageHeadroomBytes;
    if (storage.freeBytes < requiredBytes) {
    _emit(
      modelId,
      ModelDownloadState(
        stage: DownloadStage.stopped,
        errorMessage:
            'Not enough free space: ${model.name} needs about '
            '${formatBytes(model.sizeBytes)} plus a little headroom, but '
            'only ${formatBytes(storage.freeBytes)} is free.',
      ),
    );
    return;
  }
  _resumeFloors[modelId] = await _partialBytesFor(model);
  await _launch(model);
}

  @override
  void cancel(String modelId) => _controllers[modelId]?.cancel();

  @override
  Future<void> delete(String modelId) async {
    if (_active.contains(modelId)) return;
    final model = await _modelFor(modelId);
    final manager = await _ensureManager();
    await manager.remove(_sourceFor(model).cacheKey);
    _emit(modelId, const ModelDownloadState.initial());
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    for (final controller in _controllers.values) {
      await controller.dispose();
    }
    _controllers.clear();
    for (final stream in _streams.values) {
      await stream.close();
    }
    _streams.clear();
    _states.clear();
    _active.clear();
    _speedTrackers.clear();
    _resumeFloors.clear();
  }

  ModelSource _sourceFor(CatalogModel model) =>
      ModelSource.url(Uri.parse(model.downloadUrl));

  Future<CatalogModel> _modelFor(String modelId) async {
    final cached = _models[modelId];
    if (cached != null) return cached;
    final models = await _catalog.models();
    return _models[modelId] = models.firstWhere(
      (model) => model.id == modelId,
    );
  }

  Future<DefaultModelDownloadManager> _ensureManager() async {
    final existing = _manager;
    if (existing != null) return existing;
    _cacheRoot ??= await _resolveCacheDirectory();
    return _manager ??= DefaultModelDownloadManager.appPrivate(
      cacheDirectory: _cacheRoot!,
    );
  }

  Future<void> _refresh(String modelId) async {
    if (_active.contains(modelId)) {
      final current = _states[modelId];
      if (current != null) _emit(modelId, current);
      return;
    }
    final model = await _modelFor(modelId);
    final manager = await _ensureManager();
    final source = _sourceFor(model);
    final entry = await manager.get(source.cacheKey);
    if (entry != null && await File(entry.filePath).exists()) {
      _emit(
        modelId,
        ModelDownloadState(
          stage: DownloadStage.ready,
          filePath: entry.filePath,
          receivedBytes: entry.bytes ?? 0,
          totalBytes: entry.bytes,
        ),
      );
      return;
    }
    _emit(
      modelId,
      ModelDownloadState(
        stage: DownloadStage.notDownloaded,
        partialBytes: await _partialBytesFor(model),
      ),
    );
  }

  Future<void> _launch(CatalogModel model) async {
    final manager = await _ensureManager();
    final source = _sourceFor(model);
    final controller = _controllers.putIfAbsent(
      model.id,
      () => ModelDownloadController(manager: manager),
    );
    _subscriptions.putIfAbsent(
      model.id,
      () => controller.snapshots.listen(
        (snapshot) => unawaited(_handleSnapshot(model.id, snapshot)),
      ),
    );
    _active.add(model.id);
    try {
      await controller.start(source);
    } catch (_) {
      // Failures already surface through the state stream.
    } finally {
      _active.remove(model.id);
    }
  }

  Future<void> _handleSnapshot(
    String modelId,
    ModelDownloadTaskSnapshot snapshot,
  ) async {
    final progress = snapshot.progress;
    switch (snapshot.stage) {
      case ModelDownloadTaskStage.resolving:
      case ModelDownloadTaskStage.checkingCache:
        _emit(
          modelId,
          const ModelDownloadState(stage: DownloadStage.preparing),
        );
      case ModelDownloadTaskStage.downloading:
        final reported = progress?.receivedBytes ?? 0;
        final floor = _resumeFloors[modelId] ?? 0;
        final received = reported > floor ? reported : floor;
        _emit(
          modelId,
          ModelDownloadState(
            stage: DownloadStage.downloading,
            receivedBytes: received,
            totalBytes: progress?.totalBytes,
            speedBytesPerSecond: _speedTrackers
                .putIfAbsent(modelId, DownloadSpeedTracker.new)
                .update(received, DateTime.now()),
          ),
        );
      case ModelDownloadTaskStage.verifying:
        _emit(
          modelId,
          ModelDownloadState(
            stage: DownloadStage.verifying,
            receivedBytes: progress?.receivedBytes ?? 0,
            totalBytes: progress?.totalBytes,
          ),
        );
      case ModelDownloadTaskStage.ready:
        _speedTrackers.remove(modelId);
        _resumeFloors.remove(modelId);
        final bytes = snapshot.entry?.bytes;
        _emit(
          modelId,
          ModelDownloadState(
            stage: DownloadStage.ready,
            filePath: snapshot.entry?.filePath,
            receivedBytes: bytes ?? progress?.receivedBytes ?? 0,
            totalBytes: bytes ?? progress?.totalBytes,
          ),
        );
      case ModelDownloadTaskStage.failed:
      case ModelDownloadTaskStage.cancelled:
        _speedTrackers.remove(modelId);
        _resumeFloors.remove(modelId);
        final failureMessage = snapshot.errorMessage;
        final keptBytes = await _partialBytesFor(await _modelFor(modelId));
        _emit(
          modelId,
          ModelDownloadState(
            stage: DownloadStage.stopped,
            receivedBytes: progress?.receivedBytes ?? 0,
            totalBytes: progress?.totalBytes,
            partialBytes: keptBytes,
            errorMessage:
                failureMessage != null &&
                    keptBytes > 0 &&
                    isTransientNetworkError(failureMessage)
                ? null
                : failureMessage,
          ),
        );
      case ModelDownloadTaskStage.idle:
        break;
    }
  }

  Future<int> _partialBytesFor(CatalogModel model) async {
    final root = _cacheRoot;
    if (root == null) return 0;
    await _ensureManager();
    final source = _sourceFor(model);
    final partFile = File(
      p.join(root, source.cacheDirectoryName, '${source.fileName}.part'),
    );
    if (!await partFile.exists()) return 0;
    return await partFile.length();
  }

  void _emit(String modelId, ModelDownloadState state) {
    _states[modelId] = state;
    _streams[modelId]?.add(state);
  }
}
