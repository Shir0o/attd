import 'dart:io';

import 'package:attendance_tracker/features/hub/data/local_event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalJsonEventRepository', () {
    late Directory tempDir;
    late LocalJsonEventRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('event_repo_test');
      repository = LocalJsonEventRepository(storagePath: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('streamEvents emits empty list initially', () async {
      expectLater(
        repository.streamEvents(),
        emits(isEmpty),
      );
    });

    test('createEvent adds event', () async {
      final now = DateTime.now();
      final event = Event(
        id: '1',
        title: 'New Event',
        time: const TimeOfDay(hour: 10, minute: 0),
        frequency: 'Weekly',
        repeatingDays: ['Monday'],
        createdAt: now,
      );

      await repository.createEvent(event);

      final events = await repository.streamEvents().first;
      expect(events.length, 1);
      expect(events.first.id, '1');
    });

    test('updateEvent modifies existing event', () async {
      final now = DateTime.now();
      final event = Event(
        id: '1',
        title: 'Original Title',
        time: const TimeOfDay(hour: 10, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
      );

      await repository.createEvent(event);

      final updated = Event(
        id: '1',
        title: 'Updated Title',
        time: const TimeOfDay(hour: 11, minute: 0),
        frequency: 'Monthly',
        createdAt: now,
      );

      await repository.updateEvent(updated);

      final events = await repository.streamEvents().first;
      expect(events.first.title, 'Updated Title');
      expect(events.first.time.hour, 11);
    });

    test('deleteEvent removes event', () async {
      final now = DateTime.now();
      final event = Event(
        id: '1',
        title: 'To Delete',
        time: const TimeOfDay(hour: 10, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
      );

      await repository.createEvent(event);
      await repository.deleteEvent('1');

      final events = await repository.streamEvents().first;
      expect(events, isEmpty);
    });

    test('persistence works across instances', () async {
      final now = DateTime.now();
      final event = Event(
        id: '1',
        title: 'Persisted Event',
        time: const TimeOfDay(hour: 10, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
      );

      await repository.createEvent(event);

      final newRepo = LocalJsonEventRepository(storagePath: tempDir.path);

      // Wait for first emission
      final events = await newRepo.streamEvents().first;

      expect(events.length, 1);
      expect(events.first.title, 'Persisted Event');
    });
  });
}
