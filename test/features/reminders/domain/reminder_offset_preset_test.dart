import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/reminders/domain/reminder_offset_preset.dart';

void main() {
  group('ReminderOffsetPreset', () {
    test('values have correct durations and labels', () {
      expect(ReminderOffsetPreset.atStart.duration, Duration.zero);
      expect(ReminderOffsetPreset.atStart.label, 'At event start');

      expect(ReminderOffsetPreset.fifteenMinutes.duration, const Duration(minutes: 15));
      expect(ReminderOffsetPreset.thirtyMinutes.duration, const Duration(minutes: 30));
      expect(ReminderOffsetPreset.oneHour.duration, const Duration(hours: 1));
      expect(ReminderOffsetPreset.twoHours.duration, const Duration(hours: 2));
    });

    test('fromMinutes resolves matched preset or defaults to oneHour', () {
      expect(ReminderOffsetPreset.fromMinutes(0), ReminderOffsetPreset.atStart);
      expect(ReminderOffsetPreset.fromMinutes(15), ReminderOffsetPreset.fifteenMinutes);
      expect(ReminderOffsetPreset.fromMinutes(30), ReminderOffsetPreset.thirtyMinutes);
      expect(ReminderOffsetPreset.fromMinutes(60), ReminderOffsetPreset.oneHour);
      expect(ReminderOffsetPreset.fromMinutes(120), ReminderOffsetPreset.twoHours);
      expect(ReminderOffsetPreset.fromMinutes(999), ReminderOffsetPreset.oneHour);
    });
  });
}
