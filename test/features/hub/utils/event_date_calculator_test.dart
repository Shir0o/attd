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
        createdAt: now.subtract(const Duration(days: 30)),
      );

      final result = calculateTargetDate(event, now);
      expect(result, DateTime(2023, 11, 1));
    });

    test('returns today for One-time event without a scheduled date', () {
      final now = DateTime(2023, 10, 25, 10, 0);
      final event = Event(
        id: '1',
        title: 'One Time',
        time: const TimeOfDay(hour: 12, minute: 0),
        frequency: 'One-time',
        createdAt: now.subtract(const Duration(days: 30)),
      );

      final result = calculateTargetDate(event, now);
      expect(result, DateTime(2023, 10, 25));
    });

    test('returns today if time is AFTER event time (Weekly)', () {
      final now = DateTime(2023, 10, 25, 13, 0); // Wednesday, 1 PM
      final event = Event(
        id: '1',
        title: 'Weekly Event',
        time: const TimeOfDay(hour: 12, minute: 0), // 12 PM
        frequency: 'Weekly',
        repeatingDays: ['Wednesday'],
        createdAt: now.subtract(const Duration(days: 30)),
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
        createdAt: now.subtract(const Duration(days: 30)),
      );

      final result = calculateTargetDate(event, now);
      // Expect 7 days ago: Oct 18
      expect(result, DateTime(2023, 10, 18));
    });

    test('returns last occurrence if time is BEFORE event time', () {
      final now = DateTime(2023, 10, 25, 10, 0); // Wednesday
      final event = Event(
        id: '1',
        title: 'Bi-weekly Event',
        time: const TimeOfDay(hour: 12, minute: 0),
        frequency: 'Bi-weekly',
        repeatingDays: ['Wednesday'],
        createdAt: now.subtract(const Duration(days: 30)),
      );

      final result = calculateTargetDate(event, now);
      // Logic finds the most recent valid weekday (excluding today since time hasn't passed)
      // Expect 7 days ago (the last Wednesday): Oct 18
      expect(result, DateTime(2023, 10, 18));
    });

    test('returns last occurrence if time is BEFORE event time for Monthly',
        () {
      final now = DateTime(2023, 10, 25, 10, 0); // Wednesday
      final event = Event(
        id: '1',
        title: 'Monthly Event',
        time: const TimeOfDay(hour: 12, minute: 0),
        frequency: 'Monthly',
        repeatingDays: ['Wednesday'],
        createdAt: now.subtract(const Duration(days: 30)),
      );

      final result = calculateTargetDate(event, now);
      // Logic finds the most recent valid weekday (excluding today since time hasn't passed)
      // Expect 7 days ago (the last Wednesday): Oct 18
      expect(result, DateTime(2023, 10, 18));
    });

    test('returns today when no repeating days are selected', () {
      final now = DateTime(2023, 10, 25, 10, 0);
      final event = Event(
        id: '1',
        title: 'Weekly Event',
        time: const TimeOfDay(hour: 12, minute: 0),
        frequency: 'Weekly',
        repeatingDays: const [],
        createdAt: now.subtract(const Duration(days: 30)),
      );

      final result = calculateTargetDate(event, now);
      expect(result, DateTime(2023, 10, 25));
    });

    test('getLastSupposedOccurrence returns one-time date directly', () {
      final now = DateTime(2023, 10, 25, 10, 0);
      final event = Event(
        id: '1',
        title: 'One Time',
        time: const TimeOfDay(hour: 12, minute: 0),
        frequency: 'One-time',
        oneTimeDate: DateTime(2023, 11, 1, 18, 30),
        createdAt: now.subtract(const Duration(days: 30)),
      );

      final result = getLastSupposedOccurrence(event, now);
      expect(result, DateTime(2023, 11, 1));
    });

    test('does not return an occurrence before the event was created', () {
      final now = DateTime(2023, 10, 25, 10, 0);
      final event = Event(
        id: '1',
        title: 'New Weekly Event',
        time: const TimeOfDay(hour: 12, minute: 0),
        frequency: 'Weekly',
        repeatingDays: ['Wednesday'],
        createdAt: DateTime(2023, 10, 24),
      );

      final result = calculateTargetDate(event, now);
      expect(result, DateTime(2023, 10, 25));
    });
  });

  group('getNextOccurrence', () {
    test('returns the one-time date for a One-time event', () {
      final now = DateTime(2023, 10, 25, 10, 0); // Wednesday
      final event = Event(
        id: '1',
        title: 'One Time',
        time: const TimeOfDay(hour: 12, minute: 0),
        frequency: 'One-time',
        oneTimeDate: DateTime(2023, 11, 1),
        createdAt: now,
      );

      expect(getNextOccurrence(event, now), DateTime(2023, 11, 1));
    });

    test('returns today when the scheduled time is still ahead', () {
      final now = DateTime(2023, 10, 25, 10, 0); // Wednesday, 10 AM
      final event = Event(
        id: '1',
        title: 'Weekly',
        time: const TimeOfDay(hour: 12, minute: 0),
        frequency: 'Weekly',
        repeatingDays: ['Wednesday'],
        createdAt: now.subtract(const Duration(days: 30)),
      );

      expect(getNextOccurrence(event, now), DateTime(2023, 10, 25));
    });

    test('rolls forward to next week when today\'s time has passed', () {
      final now = DateTime(2023, 10, 25, 13, 0); // Wednesday, 1 PM
      final event = Event(
        id: '1',
        title: 'Weekly',
        time: const TimeOfDay(hour: 12, minute: 0),
        frequency: 'Weekly',
        repeatingDays: ['Wednesday'],
        createdAt: now.subtract(const Duration(days: 30)),
      );

      expect(getNextOccurrence(event, now), DateTime(2023, 11, 1));
    });

    test('returns the soonest upcoming weekday', () {
      final now = DateTime(2023, 10, 25, 10, 0); // Wednesday
      final event = Event(
        id: '1',
        title: 'Weekly',
        time: const TimeOfDay(hour: 12, minute: 0),
        frequency: 'Weekly',
        repeatingDays: ['Friday'],
        createdAt: now.subtract(const Duration(days: 30)),
      );

      expect(getNextOccurrence(event, now), DateTime(2023, 10, 27)); // Friday
    });

    test('returns today for a One-time event without a date', () {
      final now = DateTime(2023, 10, 25, 10, 0);
      final event = Event(
        id: '1',
        title: 'One Time',
        time: const TimeOfDay(hour: 12, minute: 0),
        frequency: 'One-time',
        createdAt: now,
      );

      expect(getNextOccurrence(event, now), DateTime(2023, 10, 25));
    });

    test('returns today when repeatingDays is empty', () {
      final now = DateTime(2023, 10, 25, 10, 0);
      final event = Event(
        id: '1',
        title: 'Weekly',
        time: const TimeOfDay(hour: 12, minute: 0),
        frequency: 'Weekly',
        repeatingDays: const [],
        createdAt: now,
      );

      expect(getNextOccurrence(event, now), DateTime(2023, 10, 25));
    });

    test('selects the soonest of multiple repeating days', () {
      final now = DateTime(2023, 10, 25, 10, 0); // Wednesday
      final event = Event(
        id: '1',
        title: 'Weekly',
        time: const TimeOfDay(hour: 12, minute: 0),
        frequency: 'Weekly',
        repeatingDays: ['Friday', 'Monday'],
        createdAt: now.subtract(const Duration(days: 30)),
      );

      // Friday (2 days away) beats Monday (5 days away).
      expect(getNextOccurrence(event, now), DateTime(2023, 10, 27));
    });
  });
}
