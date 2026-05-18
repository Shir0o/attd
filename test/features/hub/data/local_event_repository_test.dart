import 'dart:convert';
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

    test('ignores empty and malformed storage files', () async {
      final file = File('${tempDir.path}/events.json');
      await file.writeAsString('');

      expect(await repository.streamEvents().first, isEmpty);

      await file.writeAsString('{not json');
      await repository.refresh();

      expect(await repository.streamEvents().first, isEmpty);
    });

    test('findEventById returns existing event and null for missing event',
        () async {
      final now = DateTime.now();
      final event = Event(
        id: '1',
        title: 'Find Me',
        time: const TimeOfDay(hour: 10, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
      );

      await repository.createEvent(event);

      expect((await repository.findEventById('1'))?.title, 'Find Me');
      expect(await repository.findEventById('missing'), isNull);
    });

    test('updateEvent and deleteEvent ignore missing events', () async {
      final now = DateTime.now();
      final event = Event(
        id: '1',
        title: 'Only Event',
        time: const TimeOfDay(hour: 10, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
      );

      await repository.createEvent(event);
      await repository.updateEvent(
        Event(
          id: 'missing',
          title: 'Missing',
          time: const TimeOfDay(hour: 11, minute: 0),
          frequency: 'Weekly',
          createdAt: now,
        ),
      );
      await repository.deleteEvent('missing');

      final events = await repository.streamEvents().first;
      expect(events, hasLength(1));
      expect(events.single.title, 'Only Event');
    });

    test('pruneSoftDeleted removes only old deleted events', () async {
      final now = DateTime(2026, 5, 17);
      final staleDeleted = Event(
        id: 'old',
        title: 'Old Deleted',
        time: const TimeOfDay(hour: 9, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
        deletedAt: now.subtract(const Duration(days: 30)),
      );
      final recentDeleted = Event(
        id: 'recent',
        title: 'Recent Deleted',
        time: const TimeOfDay(hour: 10, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
        deletedAt: now.subtract(const Duration(days: 1)),
      );
      final active = Event(
        id: 'active',
        title: 'Active',
        time: const TimeOfDay(hour: 11, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
      );
      await File('${tempDir.path}/events.json').writeAsString(
        jsonEncode([
          staleDeleted.toJson(),
          recentDeleted.toJson(),
          active.toJson(),
        ]),
      );

      await repository.pruneSoftDeleted(now.subtract(const Duration(days: 7)));

      final reloaded = LocalJsonEventRepository(storagePath: tempDir.path);
      expect(await reloaded.findEventById('old'), isNull);
      expect((await reloaded.findEventById('recent'))?.deletedAt, isNotNull);
      expect((await reloaded.findEventById('active'))?.title, 'Active');
    });
  });
}
