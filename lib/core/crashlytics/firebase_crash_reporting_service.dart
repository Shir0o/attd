import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'crash_reporting_service.dart';

/// Concrete [CrashReportingService] delegating to Firebase Crashlytics.
class FirebaseCrashReportingService extends CrashReportingService {
  FirebaseCrashReportingService({
    required super.prefs,
    FirebaseCrashlytics? crashlytics,
  }) : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance {
    _applyCollectionState();
  }

  final FirebaseCrashlytics _crashlytics;

  Future<void> _applyCollectionState() async {
    try {
      await _crashlytics.setCrashlyticsCollectionEnabled(isCollectionEnabled);
    } catch (e) {
      debugPrint('Error updating Crashlytics collection state: $e');
    }
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    await super.setCollectionEnabled(enabled);
    await _applyCollectionState();
  }

  @override
  Future<void> log(String message) async {
    if (!isCollectionEnabled) return;
    try {
      await _crashlytics.log(message);
    } catch (e) {
      debugPrint('Crashlytics log failed: $e');
    }
  }

  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    bool fatal = false,
    Map<String, Object>? context,
  }) async {
    if (!isCollectionEnabled) return;
    try {
      if (context != null) {
        for (final entry in context.entries) {
          await _crashlytics.setCustomKey(entry.key, entry.value);
        }
      }
      await _crashlytics.recordError(
        exception,
        stack,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('Crashlytics recordError failed: $e');
    }
  }
}
