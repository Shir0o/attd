import 'package:flutter/foundation.dart';

/// Lightweight logging facade using `debugPrint`.
class AppLogger {
  const AppLogger._(this._tag);

  factory AppLogger(String tag) => AppLogger._(tag);

  final String _tag;

  void info(String message) {
    debugPrint('[$_tag] $message');
  }

  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[$_tag] WARN: $message${error != null ? ' ($error)' : ''}');
  }

  void error(String message, Object error, [StackTrace? stackTrace]) {
    debugPrint('[$_tag] ERROR: $message ($error)');
  }
}
