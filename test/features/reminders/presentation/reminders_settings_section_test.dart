import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_tracker/core/design/app_colors.dart';
import 'package:attendance_tracker/core/design/widgets/conv_primitives.dart';
import 'package:attendance_tracker/features/reminders/application/attendance_reminder_service.dart';
import 'package:attendance_tracker/features/reminders/application/reminder_settings_controller.dart';
import 'package:attendance_tracker/features/reminders/domain/reminder_offset_preset.dart';
import 'package:attendance_tracker/features/reminders/presentation/reminders_settings_section.dart';

class MockAttendanceReminderService extends Mock
    implements AttendanceReminderService {}

void main() {
  Widget buildTestable(
    ReminderSettingsController controller, {
    AttendanceReminderService? reminderService,
  }) {
    return MaterialApp(
      theme: ThemeData(
        extensions: const [
          ConvocationColors.light,
        ],
      ),
      home: Scaffold(
        body: RemindersSettingsSection(
          controller: controller,
          reminderService: reminderService,
        ),
      ),
    );
  }

  group('RemindersSettingsSection', () {
    testWidgets('renders toggle off and hides offset selector initially', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = ReminderSettingsController(prefs: prefs);

      await tester.pumpWidget(buildTestable(controller));
      await tester.pumpAndSettle();

      expect(find.text('Attendance Reminders'), findsOneWidget);
      expect(find.text('REMINDER OFFSET'), findsNothing);
    });

    testWidgets('enabling toggle reveals offset selector and defaults to 1 hour after', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = ReminderSettingsController(prefs: prefs);

      await tester.pumpWidget(buildTestable(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ConvToggle));
      await tester.pumpAndSettle();

      expect(controller.enabled, true);
      expect(find.text('REMINDER OFFSET'), findsOneWidget);
      expect(find.text('1 hour after'), findsOneWidget);
    });

    testWidgets('selecting different preset updates controller offset', (tester) async {
      SharedPreferences.setMockInitialValues({
        ReminderSettingsController.enabledKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final controller = ReminderSettingsController(prefs: prefs);

      await tester.pumpWidget(buildTestable(controller));
      await tester.pumpAndSettle();

      expect(find.text('1 hour after'), findsOneWidget);

      await tester.tap(find.text('1 hour after'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('30 minutes after').last);
      await tester.pumpAndSettle();

      expect(controller.offset, ReminderOffsetPreset.thirtyMinutes);
      expect(find.text('30 minutes after'), findsOneWidget);
    });

    testWidgets('enabling toggle requests permissions; enables and syncs when granted', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = ReminderSettingsController(prefs: prefs);
      final mockService = MockAttendanceReminderService();

      when(() => mockService.requestPermissions()).thenAnswer((_) async => true);
      when(() => mockService.syncReminders()).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestable(controller, reminderService: mockService));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ConvToggle));
      await tester.pumpAndSettle();

      verify(() => mockService.requestPermissions()).called(1);
      verify(() => mockService.syncReminders()).called(1);
      expect(controller.enabled, isTrue);
    });

    testWidgets('enabling toggle does not enable when permission is denied', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = ReminderSettingsController(prefs: prefs);
      final mockService = MockAttendanceReminderService();

      when(() => mockService.requestPermissions()).thenAnswer((_) async => false);

      await tester.pumpWidget(buildTestable(controller, reminderService: mockService));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ConvToggle));
      await tester.pumpAndSettle();

      verify(() => mockService.requestPermissions()).called(1);
      verifyNever(() => mockService.syncReminders());
      expect(controller.enabled, isFalse);
    });

    testWidgets('changing offset calls syncReminders on reminderService', (tester) async {
      SharedPreferences.setMockInitialValues({
        ReminderSettingsController.enabledKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final controller = ReminderSettingsController(prefs: prefs);
      final mockService = MockAttendanceReminderService();

      when(() => mockService.syncReminders()).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestable(controller, reminderService: mockService));
      await tester.pumpAndSettle();

      await tester.tap(find.text('1 hour after'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('15 minutes after').last);
      await tester.pumpAndSettle();

      expect(controller.offset, ReminderOffsetPreset.fifteenMinutes);
      verify(() => mockService.syncReminders()).called(1);
    });
  });
}
