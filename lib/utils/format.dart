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

String formatSpeed(double bytesPerSecond) {
  const mb = 1000 * 1000;
  if (bytesPerSecond < 1000) return '${bytesPerSecond.round()} B/s';
  if (bytesPerSecond < mb) return '${(bytesPerSecond / 1000).round()} KB/s';
  final value = bytesPerSecond / mb;
  return value >= 100
      ? '${value.round()} MB/s'
      : '${value.toStringAsFixed(1)} MB/s';
}

/// Compact "2h ago" label for the conversation list. [now] is injectable
/// for tests; production callers leave it null.
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final difference = current.difference(time);
  if (difference.isNegative || difference.inMinutes < 1) return 'just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final date = '${months[time.month - 1]} ${time.day}';
  return time.year == current.year ? date : '$date ${time.year}';
}
