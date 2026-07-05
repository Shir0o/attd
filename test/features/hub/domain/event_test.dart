import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_start_mode.dart';
import 'package:attendance_tracker/features/attendance/models/roster_grouping.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Event', () {
    final now = DateTime.now();
    final event = Event(
      id: 'event-1',
      title: 'Sunday Service',
      time: const TimeOfDay(hour: 10, minute: 30),
      frequency: 'Weekly',
      repeatingDays: ['Sunday'],
      createdAt: now,
      updatedAt: now,
    );

    test('toJson and fromJson work correctly', () {
      final json = event.toJson();
      expect(json['id'], 'event-1');
      expect(json['title'], 'Sunday Service');
      expect(json['time'], '10:30');
      expect(json['frequency'], 'Weekly');
      expect(json['repeatingDays'], ['Sunday']);
      expect(json['createdAt'], now.toIso8601String());

      final fromJson = Event.fromJson(json);
      expect(fromJson.id, event.id);
      expect(fromJson.title, event.title);
      expect(fromJson.time.hour, 10);
      expect(fromJson.time.minute, 30);
      expect(fromJson.frequency, 'Weekly');
      expect(fromJson.repeatingDays, ['Sunday']);
    });

    test('fromJson handles one-time events', () {
      final oneTimeDate = DateTime(2024, 12, 25);
      final json = {
        'id': 'event-2',
        'title': 'Christmas Special',
        'time': '18:00',
        'frequency': 'One-time',
        'oneTimeDate': oneTimeDate.toIso8601String(),
        'createdAt': now.toIso8601String(),
      };

      final fromJson = Event.fromJson(json);
      expect(fromJson.frequency, 'One-time');
      expect(fromJson.oneTimeDate, oneTimeDate);
      expect(fromJson.repeatingDays, isEmpty);
    });

    test('fromJson handles missing updatedAt by using createdAt', () {
      final json = {
        'id': 'event-3',
        'title': 'Legacy Event',
        'time': '09:00',
        'frequency': 'Monthly',
        'createdAt': now.toIso8601String(),
        // updatedAt missing
      };

      final fromJson = Event.fromJson(json);
      expect(fromJson.updatedAt, fromJson.createdAt);
    });

    test('title should be trimmed', () {
      final untrimmed = Event(
        id: 'event-4',
        title: '  Trim Me  ',
        time: const TimeOfDay(hour: 9, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
      );
      expect(untrimmed.title, 'Trim Me');

      final json = {
        'id': 'event-5',
        'title': '  Json Trim  ',
        'time': '10:0',
        'frequency': 'Weekly',
        'createdAt': now.toIso8601String(),
      };
      final fromJson = Event.fromJson(json);
      expect(fromJson.title, 'Json Trim');
    });

    test('toJson and fromJson handle defaultAttendanceStartMode and rosterGrouping', () {
      final eventWithPresets = Event(
        id: 'event-presets',
        title: 'Preset Event',
        time: const TimeOfDay(hour: 11, minute: 0),
        frequency: 'Weekly',
        defaultAttendanceStartMode: AttendanceStartMode.allAbsent,
        rosterGrouping: RosterGrouping.byFamily,
        createdAt: now,
      );

      final json = eventWithPresets.toJson();
      expect(json['defaultAttendanceStartMode'], 'allAbsent');
      expect(json['rosterGrouping'], 'byFamily');

      final fromJson = Event.fromJson(json);
      expect(fromJson.defaultAttendanceStartMode, AttendanceStartMode.allAbsent);
      expect(fromJson.rosterGrouping, RosterGrouping.byFamily);
    });

    test('copyWith works correctly', () {
      final baseEvent = Event(
        id: 'base',
        title: 'Base',
        time: const TimeOfDay(hour: 9, minute: 0),
        frequency: 'One-time',
        createdAt: now,
        deletedAt: now,
      );

      final noChanges = baseEvent.copyWith();
      expect(noChanges.id, 'base');
      expect(noChanges.title, 'Base');
      expect(noChanges.deletedAt, now);

      final changed = baseEvent.copyWith(
        id: 'new-id',
        title: 'New Title',
        time: const TimeOfDay(hour: 10, minute: 0),
        frequency: 'Weekly',
        clearDeletedAt: true,
      );
      expect(changed.id, 'new-id');
      expect(changed.title, 'New Title');
      expect(changed.time.hour, 10);
      expect(changed.frequency, 'Weekly');
      expect(changed.deletedAt, isNull);
    });
  });
}

