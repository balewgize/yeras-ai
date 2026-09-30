import 'package:flutter_test/flutter_test.dart';

import 'package:yeras_ai/utils/download_errors.dart';

void main() {
  group('transient network errors are silenced', () {
    test('socket killed by backgrounding', () {
      expect(
        isTransientNetworkError(
          'LlamaModelException: Failed to download model.gguf. '
          'Caused by: SocketException: Connection failed '
          '(OS Error: Network is unreachable, errno = 101)',
        ),
        isTrue,
      );
    });

    test('connection closed mid-body', () {
      expect(
        isTransientNetworkError(
          'HttpException: Connection closed while receiving data',
        ),
        isTrue,
      );
    });

    test('stalled socket timeout', () {
      expect(
        isTransientNetworkError(
          'HttpException: Timed out waiting for download data.',
        ),
        isTrue,
      );
    });
  });

  group('real errors are shown', () {
    test('rate limiting', () {
      expect(
        isTransientNetworkError(
          'Failed to download model.gguf: HTTP 429.',
        ),
        isFalse,
      );
    });

    test('server error', () {
      expect(
        isTransientNetworkError(
          'Failed to download model.gguf: HTTP 503.',
        ),
        isFalse,
      );
    });

    test('missing file', () {
      expect(
        isTransientNetworkError(
          'Failed to download model.gguf: HTTP 404.',
        ),
        isFalse,
      );
    });

    test('checksum mismatch', () {
      expect(
        isTransientNetworkError('Checksum mismatch for model.gguf.'),
        isFalse,
      );
    });

    test('storage refusal', () {
      expect(
        isTransientNetworkError(
          'Not enough free space: Test Model needs about 810 MB plus a '
          'little headroom, but only 100 MB is free.',
        ),
        isFalse,
      );
    });

    test('unknown errors stay visible', () {
      expect(isTransientNetworkError('Something broke.'), isFalse);
    });
  });
}
