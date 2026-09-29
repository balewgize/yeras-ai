enum DownloadStage {
  notDownloaded,
  preparing,
  downloading,
  verifying,
  ready,
  stopped,
}

class ModelDownloadState {
  const ModelDownloadState({
    required this.stage,
    this.receivedBytes = 0,
    this.totalBytes,
    this.partialBytes = 0,
    this.errorMessage,
    this.filePath,
    this.speedBytesPerSecond,
  });

  const ModelDownloadState.initial() : this(stage: DownloadStage.notDownloaded);

  final DownloadStage stage;
  final int receivedBytes;
  final int? totalBytes;
  final int partialBytes;
  final String? errorMessage;
  final String? filePath;
  final double? speedBytesPerSecond;

  bool get isActive =>
      stage == DownloadStage.preparing ||
      stage == DownloadStage.downloading ||
      stage == DownloadStage.verifying;

  double? get fraction {
    if (stage == DownloadStage.ready) return 1.0;
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    final value = receivedBytes / total;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }
}
