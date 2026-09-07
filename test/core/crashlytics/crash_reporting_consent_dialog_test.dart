import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/core/crashlytics/crash_reporting_service.dart';
import 'package:attendance_tracker/core/crashlytics/crash_reporting_consent_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CrashReportingConsentDialog', () {
    testWidgets('prompts user and records consent when accepted', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = LocalCrashReportingService(prefs: prefs);

      expect(service.hasAskedConsent, isFalse);
      expect(service.isCollectionEnabled, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CrashReportingConsentDialog.promptIfNeeded(context, service: service);
                },
                child: const Text('Open Prompt'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Prompt'));
      await tester.pumpAndSettle();

      expect(find.text('Help improve Attendance?'), findsOneWidget);
      expect(find.textContaining('Send anonymous crash diagnostics'), findsOneWidget);
      expect(find.text('No thanks'), findsOneWidget);
      expect(find.text('Agree & Share'), findsOneWidget);

      await tester.tap(find.text('Agree & Share'));
      await tester.pumpAndSettle();

      expect(service.hasAskedConsent, isTrue);
      expect(service.isCollectionEnabled, isTrue);
    });

    testWidgets('prompts user and sets collection disabled when declined', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = LocalCrashReportingService(prefs: prefs);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CrashReportingConsentDialog.promptIfNeeded(context, service: service);
                },
                child: const Text('Open Prompt'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Prompt'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('No thanks'));
      await tester.pumpAndSettle();

      expect(service.hasAskedConsent, isTrue);
      expect(service.isCollectionEnabled, isFalse);
    });

    testWidgets('does not prompt if consent was already asked', (tester) async {
      SharedPreferences.setMockInitialValues({
        CrashReportingService.crashReportingPromptShownKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = LocalCrashReportingService(prefs: prefs);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CrashReportingConsentDialog.promptIfNeeded(context, service: service);
                },
                child: const Text('Open Prompt'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Prompt'));
      await tester.pumpAndSettle();

      expect(find.text('Help improve Attendance?'), findsNothing);
    });
  });
}
