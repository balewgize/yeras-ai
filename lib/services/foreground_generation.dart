import 'dart:async' show FutureOr, unawaited;
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Best-effort Android foreground service that keeps the process alive
/// while a model loads or a reply streams, so backgrounding the app does
/// not freeze or kill on-device generation (Phase 6).
///
/// Runs only while the chat controller is busy and stops the moment it goes
/// idle. Failures are swallowed: generation always continues in-process,
/// and if the OS kills it anyway, the persisted conversation surfaces the
/// interrupted reply at next launch (Phase 7) — never silently.
///
/// [onPlatformStart] / [onPlatformStop] replace the channel calls in tests
/// while keeping this class's dedup and error semantics intact.
class ForegroundGenerationService {
  ForegroundGenerationService({
    bool Function()? isAndroidCheck,
    FutureOr<void> Function()? onPlatformStart,
    FutureOr<void> Function()? onPlatformStop,
  }) : _isAndroid = isAndroidCheck ?? _defaultIsAndroid,
       _onPlatformStart = onPlatformStart,
       _onPlatformStop = onPlatformStop;

  static const MethodChannel _channel = MethodChannel(
    'staylocal/foreground_generation',
  );

  static bool _defaultIsAndroid() => Platform.isAndroid;

  final bool Function() _isAndroid;
  final FutureOr<void> Function()? _onPlatformStart;
  final FutureOr<void> Function()? _onPlatformStop;
  bool _running = false;
  bool _permissionRequested = false;

  /// True only where the platform channel is wired (Android).
  bool get isSupported => _isAndroid();

  Future<void> start() async {
    if (!_isAndroid() || _running) return;
    _running = true;
    if (!_permissionRequested) {
      _permissionRequested = true;
      // Fire-and-forget: the ask only controls notification visibility and
      // must never delay or block starting the service.
      unawaited(
        _channel
            .invokeMethod<void>('requestNotificationPermission')
            .then<void>((_) {}, onError: (Object _) {}),
      );
    }
    try {
      final hook = _onPlatformStart;
      if (hook != null) {
        await hook();
      } else {
        await _channel.invokeMethod<void>('startGeneration');
      }
    } catch (_) {
      // Best effort: generation continues in-process; an OS kill then
      // surfaces via the interrupted-reply state at next launch.
      _running = false;
    }
  }

  Future<void> stop() async {
    if (!_isAndroid() || !_running) return;
    _running = false;
    try {
      final hook = _onPlatformStop;
      if (hook != null) {
        await hook();
      } else {
        await _channel.invokeMethod<void>('stopGeneration');
      }
    } catch (_) {
      // Ignored: the service dies with the app anyway.
    }
  }
}
