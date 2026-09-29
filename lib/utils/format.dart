String formatBytes(int bytes) {
  const gb = 1000 * 1000 * 1000;
  const mb = 1000 * 1000;
  if (bytes >= gb) {
    final value = bytes / gb;
    return value >= 100
        ? '${value.round()} GB'
        : '${value.toStringAsFixed(1)} GB';
  }
  if (bytes >= mb) return '${(bytes / mb).round()} MB';
  return '$bytes B';
}
