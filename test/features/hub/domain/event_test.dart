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
  });
}
