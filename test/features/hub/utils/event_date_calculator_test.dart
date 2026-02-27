import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/hub/utils/event_date_utils.dart';

void main() {
  group('calculateTargetDate', () {
    test('returns one-time date for One-time event', () {
      final now = DateTime(2023, 10, 25, 10, 0); // Wednesday
      final oneTimeDate = DateTime(2023, 11, 1);
      final event = Event(
        id: '1',
        title: 'One Time',
        time: const TimeOfDay(hour: 12, minute: 0),
        frequency: 'One-time',
        oneTimeDate: oneTimeDate,
        createdAt: DateTime.now(),
      );

      final result = calculateTargetDate(event, now);
      expect(result, DateTime(2023, 11, 1));
    });

    test('returns today if time is AFTER event time (Weekly)', () {
      final now = DateTime(2023, 10, 25, 13, 0); // Wednesday, 1 PM
      final event = Event(
        id: '1',
        title: 'Weekly Event',
        time: const TimeOfDay(hour: 12, minute: 0), // 12 PM
        frequency: 'Weekly',
        repeatingDays: ['Wednesday'],
        createdAt: DateTime.now(),
      );

      final result = calculateTargetDate(event, now);
      expect(result, DateTime(2023, 10, 25));
    });

    test('returns last week if time is BEFORE event time (Weekly)', () {
      final now = DateTime(2023, 10, 25, 10, 0); // Wednesday, 10 AM
      final event = Event(
        id: '1',
        title: 'Weekly Event',
        time: const TimeOfDay(hour: 12, minute: 0), // 12 PM
        frequency: 'Weekly',
        repeatingDays: ['Wednesday'],
        createdAt: DateTime.now(),
      );

      final result = calculateTargetDate(event, now);
      // Expect 7 days ago: Oct 18
      expect(result, DateTime(2023, 10, 18));
    });

    test('returns 2 weeks ago if time is BEFORE event time (Bi-weekly)', () {
      final now = DateTime(2023, 10, 25, 10, 0);
      final event = Event(
        id: '1',
        title: 'Bi-weekly Event',
        time: const TimeOfDay(hour: 12, minute: 0),
        frequency: 'Bi-weekly',
        repeatingDays: ['Wednesday'],
        createdAt: DateTime.now(),
      );

      final result = calculateTargetDate(event, now);
      // Expect 14 days ago: Oct 11
      expect(result, DateTime(2023, 10, 11));
    });

    test('returns last month if time is BEFORE event time (Monthly)', () {
      final now = DateTime(2023, 10, 25, 10, 0);
      final event = Event(
        id: '1',
        title: 'Monthly Event',
        time: const TimeOfDay(hour: 12, minute: 0),
        frequency: 'Monthly',
        repeatingDays: ['Wednesday'],
        createdAt: DateTime.now(),
      );

      final result = calculateTargetDate(event, now);
      // Expect 1 month ago: Sept 25
      expect(result, DateTime(2023, 9, 25));
    });
  });
}
