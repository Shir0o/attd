import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Lightweight logging facade.
///
/// `info` is a no-op in release builds (uses `debugPrint`).
/// `warning` and `error` route through Crashlytics as non-fatals when
/// Firebase is initialized, and fall back to `debugPrint` otherwise so tests
/// and uninitialized environments don't crash.
class AppLogger {
  const AppLogger._(this._tag);

  factory AppLogger(String tag) => AppLogger._(tag);

  final String _tag;

  void info(String message) {
    debugPrint('[$_tag] $message');
  }

  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[$_tag] WARN: $message${error != null ? ' ($error)' : ''}');
    _reportNonFatal(message, error, stackTrace);
  }

  void error(String message, Object error, [StackTrace? stackTrace]) {
    debugPrint('[$_tag] ERROR: $message ($error)');
    _reportNonFatal(message, error, stackTrace);
  }

  static void _reportNonFatal(
    String reason,
    Object? error,
    StackTrace? stackTrace,
  ) {
    if (error == null) return;
    if (Firebase.apps.isEmpty) return;
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: false,
      );
    } catch (_) {
      // Crashlytics not available; debugPrint above is enough.
    }
  }
}
