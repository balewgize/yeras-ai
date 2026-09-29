class DownloadSpeedTracker {
  DownloadSpeedTracker({
    this.emitInterval = const Duration(milliseconds: 500),
  });

  final Duration emitInterval;

  bool _hasSample = false;
  int _receivedBytes = 0;
  DateTime? _at;
  double _smoothed = 0;
  double? _emitted;
  DateTime? _emittedAt;

  double? update(int receivedBytes, DateTime now) {
    if (!_hasSample) {
      _receivedBytes = receivedBytes;
      _at = now;
      _hasSample = true;
      return null;
    }
    final elapsedSeconds = now.difference(_at!).inMicroseconds / 1e6;
    _at = now;
    if (elapsedSeconds > 0 && receivedBytes >= _receivedBytes) {
      final instant = (receivedBytes - _receivedBytes) / elapsedSeconds;
      _smoothed = _smoothed * 0.7 + instant * 0.3;
      _receivedBytes = receivedBytes;
    }
    if (_emitted == null || now.difference(_emittedAt!) >= emitInterval) {
      _emitted = _smoothed > 0 ? _smoothed : null;
      _emittedAt = now;
    }
    return _emitted;
  }
}
