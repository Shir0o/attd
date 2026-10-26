import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_tracker/features/reminders/application/reminder_settings_controller.dart';
import 'package:attendance_tracker/features/reminders/domain/reminder_offset_preset.dart';

void main() {
  group('ReminderSettingsController', () {
    test('loads default values when prefs are empty', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = ReminderSettingsController(prefs: prefs);

      expect(controller.enabled, false);
      expect(controller.offset, ReminderOffsetPreset.oneHour);
    });

    test('loads persisted values from prefs', () async {
      SharedPreferences.setMockInitialValues({
        ReminderSettingsController.enabledKey: true,
        ReminderSettingsController.offsetMinutesKey: 30,
      });
      final prefs = await SharedPreferences.getInstance();
      final controller = ReminderSettingsController(prefs: prefs);

      expect(controller.enabled, true);
      expect(controller.offset, ReminderOffsetPreset.thirtyMinutes);
    });

    test('setEnabled persists value and notifies listeners', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = ReminderSettingsController(prefs: prefs);

      bool notified = false;
      controller.addListener(() => notified = true);

      await controller.setEnabled(true);

      expect(controller.enabled, true);
      expect(notified, true);
      expect(prefs.getBool(ReminderSettingsController.enabledKey), true);
    });

    test('setOffset persists value and notifies listeners', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = ReminderSettingsController(prefs: prefs);

      bool notified = false;
      controller.addListener(() => notified = true);

      await controller.setOffset(ReminderOffsetPreset.twoHours);

      expect(controller.offset, ReminderOffsetPreset.twoHours);
      expect(notified, true);
      expect(prefs.getInt(ReminderSettingsController.offsetMinutesKey), 120);
    });
  });
}
