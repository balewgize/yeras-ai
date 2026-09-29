const List<String> _transientPatterns = <String>[
  'socketexception',
  'httpexception',
  'connection closed',
  'connection reset',
  'connection refused',
  'connection failed',
  'network is unreachable',
  'broken pipe',
  'software caused connection abort',
  'timed out',
];

bool isTransientNetworkError(String message) {
  final text = message.toLowerCase();
  return _transientPatterns.any(text.contains);
}
