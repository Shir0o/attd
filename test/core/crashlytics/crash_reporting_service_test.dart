import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/core/crashlytics/crash_reporting_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestCrashReportingService extends CrashReportingService {
  TestCrashReportingService({required super.prefs});

  final List<RecordedError> recordedErrors = [];

  @override
  Future<void> log(String message) async {
    // Record log message
  }

  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    bool fatal = false,
    Map<String, Object>? context,
  }) async {
    if (!isCollectionEnabled) return;
    recordedErrors.add(RecordedError(
      exception: exception,
      stack: stack,
      fatal: fatal,
      context: context,
    ));
  }
}

class RecordedError {
  RecordedError({
    required this.exception,
    this.stack,
    this.fatal = false,
    this.context,
  });

  final dynamic exception;
  final StackTrace? stack;
  final bool fatal;
  final Map<String, Object>? context;
}

void main() {
  group('CrashReportingService & Consent Lifecycle', () {
    test('defaults to collection disabled and prompt not yet asked', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = TestCrashReportingService(prefs: prefs);

      expect(service.isCollectionEnabled, isFalse);
      expect(service.hasAskedConsent, isFalse);
    });

    test('suppresses error recording when collection is disabled', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = TestCrashReportingService(prefs: prefs);

      await service.recordError(Exception('test'), null);
      expect(service.recordedErrors, isEmpty);
    });

    test('records errors when collection is enabled with consent', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = TestCrashReportingService(prefs: prefs);

      await service.setCollectionEnabled(true);

      expect(service.isCollectionEnabled, isTrue);
      expect(service.hasAskedConsent, isTrue);
      expect(prefs.getBool(CrashReportingService.crashReportingEnabledKey), isTrue);
      expect(prefs.getBool(CrashReportingService.crashReportingPromptShownKey), isTrue);

      await service.recordError(Exception('diagnostic error'), null, fatal: false);
      expect(service.recordedErrors.length, 1);
      expect(service.recordedErrors.first.exception.toString(), contains('diagnostic error'));
    });

    test('updates preference when consent is declined', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = TestCrashReportingService(prefs: prefs);

      await service.setCollectionEnabled(false);

      expect(service.isCollectionEnabled, isFalse);
      expect(service.hasAskedConsent, isTrue);
      expect(prefs.getBool(CrashReportingService.crashReportingEnabledKey), isFalse);
      expect(prefs.getBool(CrashReportingService.crashReportingPromptShownKey), isTrue);
    });
  });
}
