import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_tracker/core/design/app_colors.dart';
import 'package:attendance_tracker/core/design/widgets/conv_primitives.dart';
import 'package:attendance_tracker/features/reminders/application/reminder_settings_controller.dart';
import 'package:attendance_tracker/features/reminders/domain/reminder_offset_preset.dart';
import 'package:attendance_tracker/features/reminders/presentation/reminders_settings_section.dart';

void main() {
  Widget buildTestable(ReminderSettingsController controller) {
    return MaterialApp(
      theme: ThemeData(
        extensions: const [
          ConvocationColors.light,
        ],
      ),
      home: Scaffold(
        body: RemindersSettingsSection(controller: controller),
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
  });
}
