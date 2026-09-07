import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Abstract service managing diagnostic crash reporting and user telemetry consent.
abstract class CrashReportingService extends ChangeNotifier {
  CrashReportingService({required this.prefs}) {
    _isCollectionEnabled = prefs.getBool(crashReportingEnabledKey) ?? false;
  }

  static const String crashReportingEnabledKey = 'crash_reporting_enabled';
  static const String crashReportingPromptShownKey = 'crash_reporting_prompt_shown';

  final SharedPreferences prefs;
  late bool _isCollectionEnabled;

  /// Whether diagnostic telemetry collection is currently permitted by the user.
  bool get isCollectionEnabled => _isCollectionEnabled;

  /// Whether the user has been shown the initial consent prompt.
  bool get hasAskedConsent => prefs.getBool(crashReportingPromptShownKey) ?? false;

  /// Updates crash reporting consent and persists it to preferences.
  Future<void> setCollectionEnabled(bool enabled) async {
    _isCollectionEnabled = enabled;
    await prefs.setBool(crashReportingEnabledKey, enabled);
    await prefs.setBool(crashReportingPromptShownKey, true);
    notifyListeners();
  }

  /// Appends a diagnostic breadcrumb or log message.
  Future<void> log(String message);

  /// Records an uncaught or caught exception with optional sanitized context.
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    bool fatal = false,
    Map<String, Object>? context,
  });
}

/// A lightweight local-only / no-op crash reporting service for testing and debug runs.
class LocalCrashReportingService extends CrashReportingService {
  LocalCrashReportingService({required super.prefs});

  @override
  Future<void> log(String message) async {
    debugPrint('[DiagnosticLog] $message');
  }

  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    bool fatal = false,
    Map<String, Object>? context,
  }) async {
    if (!isCollectionEnabled) return;
    debugPrint('[DiagnosticError] (fatal: $fatal) $exception');
    if (context != null && context.isNotEmpty) {
      debugPrint('[DiagnosticContext] $context');
    }
    if (stack != null) {
      debugPrint('[DiagnosticStack] $stack');
    }
  }
}
