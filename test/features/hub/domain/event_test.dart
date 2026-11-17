import 'package:attendance_tracker/features/hub/domain/event.dart';
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

    test(
        'old JSON carrying the removed preset keys still loads, and they are dropped',
        () {
      final json = Event(
        id: 'event-presets',
        title: 'Preset Event',
        time: const TimeOfDay(hour: 11, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
      ).toJson()
        ..['defaultAttendanceStartMode'] = 'allPresent'
        ..['rosterGrouping'] = 'byFamily'
        ..['markingMode'] = 'rapidEntry';

      final fromJson = Event.fromJson(json);
      expect(fromJson.id, 'event-presets');
      expect(fromJson.title, 'Preset Event');

      final rewritten = fromJson.toJson();
      expect(rewritten.containsKey('defaultAttendanceStartMode'), isFalse);
      expect(rewritten.containsKey('rosterGrouping'), isFalse);
      expect(rewritten.containsKey('markingMode'), isFalse);
    });

    test('unrecognised values under the removed keys are ignored too', () {
      final json = Event(
        id: 'e2',
        title: 'Odd',
        time: const TimeOfDay(hour: 9, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
      ).toJson()
        ..['markingMode'] = 'teleportation'
        ..['rosterGrouping'] = 42;

      expect(() => Event.fromJson(json), returnsNormally);
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

    test('handoffEventId marks an event as handed off and round trips', () {
      final handedOff = Event(
        id: 'handoff:ev-1',
        title: 'Sunday Service',
        time: const TimeOfDay(hour: 10, minute: 0),
        frequency: 'One-time',
        createdAt: now,
        handoffEventId: 'ev-1',
      );
      expect(handedOff.isHandedOff, isTrue);
      expect(handedOff.toJson()['handoffEventId'], 'ev-1');
      expect(Event.fromJson(handedOff.toJson()).handoffEventId, 'ev-1');
      expect(handedOff.copyWith(title: 'Renamed').handoffEventId, 'ev-1');
    });

    test('an ordinary event is not handed off and writes no marker', () {
      final ordinary = Event(
        id: 'e1',
        title: 'Own',
        time: const TimeOfDay(hour: 10, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
      );
      expect(ordinary.isHandedOff, isFalse);
      expect(ordinary.toJson().containsKey('handoffEventId'), isFalse);
    });
  });

  group('Event with legacy Drive-sharing keys', () {
    // Drive sharing was removed. Files written by it still carry its keys;
    // they must load as an ordinary event and the keys must not be written.
    final now = DateTime(2025, 1, 1);

    test('loads, ignores the keys, and does not write them back', () {
      final legacy = <String, dynamic>{
        'id': 'e-shared',
        'title': 'Was Shared',
        'time': '9:30',
        'frequency': 'Weekly',
        'repeatingDays': ['Sunday'],
        'memberIds': ['m1'],
        'isShared': true,
        'sharedFolderId': 'folder-123',
        'collaborators': ['collab@example.com'],
        'isReadOnly': true,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final event = Event.fromJson(legacy);
      expect(event.id, 'e-shared');
      expect(event.memberIds, ['m1']);
      expect(event.isHandedOff, isFalse);

      final json = event.toJson();
      for (final key in [
        'isShared',
        'sharedFolderId',
        'collaborators',
        'isReadOnly',
      ]) {
        expect(json.containsKey(key), isFalse, reason: key);
      }
    });
  });
  group('Event with legacy Insights keys', () {
    // Insights and its per-event presets were removed. Local files, Drive
    // backups and shared slices written before then still carry the keys; they
    // must load and be ignored.
    final legacy = <String, dynamic>{
      'id': 'e1',
      'title': 'Wednesday Study',
      'time': '19:0',
      'frequency': 'Weekly',
      'createdAt': '2026-01-01T00:00:00.000',
      'insightsRange': 'year',
      'insightsRegularThresholdPercent': 60,
      'insightsRegularWindow': 12,
      'insightsLapsedConsecutiveMisses': 2,
      'insightsLapsedMinimumPriorSessions': 6,
      'insightsVisibleSections': ['rateOverTime', 'notASection'],
    };

    test('loads without error and keeps its other fields', () {
      final event = Event.fromJson(Map<String, dynamic>.of(legacy));

      expect(event.id, 'e1');
      expect(event.title, 'Wednesday Study');
      expect(event.frequency, 'Weekly');
    });

    test('malformed legacy values are ignored too', () {
      final event = Event.fromJson({
        ...legacy,
        'insightsRegularThresholdPercent': 'sixty',
        'insightsVisibleSections': 'regulars',
      });

      expect(event.id, 'e1');
    });

    test('does not write the keys back out', () {
      final json = Event.fromJson(Map<String, dynamic>.of(legacy)).toJson();

      expect(json.keys.where((k) => k.startsWith('insights')), isEmpty);
    });

    test('leaves the check-on fields untouched', () {
      final event = Event.fromJson({
        ...legacy,
        'checkOnStopFlagging': ['m2'],
        'checkOnFollowUps': {
          'm1': {'flag': 'goneQuiet', 'lastPresent': '2026-02-03'},
        },
      });

      expect(event.checkOnStopFlagging, {'m2'});
      expect(event.checkOnFollowUps.keys, ['m1']);
    });
  });
}
