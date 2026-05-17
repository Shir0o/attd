import 'dart:async';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/hub/presentation/add_event_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _EventRepository implements EventRepository {
  final List<Event> events;
  int createCount = 0;
  int updateCount = 0;
  int deleteCount = 0;

  _EventRepository([List<Event>? initial]) : events = [...?initial];

  @override
  Future<void> createEvent(Event event) async {
    createCount++;
    events.add(event);
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    deleteCount++;
    events.removeWhere((event) => event.id == eventId);
  }

  @override
  Future<Event?> findEventById(String eventId) async =>
      events.where((event) => event.id == eventId).firstOrNull;

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<void> refresh() async {}

  @override
  Stream<List<Event>> streamEvents() => Stream.value(events);

  @override
  Future<void> updateEvent(Event event) async {
    updateCount++;
    final index = events.indexWhere((item) => item.id == event.id);
    if (index == -1) {
      events.add(event);
    } else {
      events[index] = event;
    }
  }
}

class _SessionRepository implements SessionRepository {
  final List<Session> sessions;

  _SessionRepository(this.sessions);

  @override
  Future<Session> createSession({
    required String title,
    String? eventId,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {}

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async {
    throw UnimplementedError();
  }

  @override
  Future<Session?> findSessionById(String id) async => null;

  @override
  Future<List<SessionVersion>> history(String sessionId) async => [];

  @override
  Future<List<Session>> loadSessions() async => sessions;

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async =>
      session;

  @override
  Stream<List<Session>> streamSessions() => Stream.value(sessions);
}

Widget _wrap(Widget child) {
  return MaterialApp(home: child);
}

void main() {
  testWidgets('creates a weekly event', (tester) async {
    final repository = _EventRepository();

    await tester.pumpWidget(
      _wrap(
        AddEventPage(
          eventRepository: repository,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '  Choir Practice  ');
    await tester.tap(find.byKey(const ValueKey('save_event_button')));
    await tester.pumpAndSettle();

    expect(repository.createCount, 1);
    expect(repository.events.single.title, 'Choir Practice');
    expect(repository.events.single.frequency, 'Weekly');
    expect(repository.events.single.repeatingDays, isNotEmpty);
  });

  testWidgets('validates event name before saving', (tester) async {
    final repository = _EventRepository();

    await tester.pumpWidget(
      _wrap(
        AddEventPage(
          eventRepository: repository,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('save_event_button')));
    await tester.pump();

    expect(find.text('Please enter an event name'), findsOneWidget);
    expect(repository.createCount, 0);
  });

  testWidgets('deletes an event with linked session warning', (
    tester,
  ) async {
    final createdAt = DateTime(2025, 1, 1);
    final event = Event(
      id: 'event-1',
      title: 'Original',
      time: const TimeOfDay(hour: 9, minute: 30),
      frequency: 'Monthly',
      createdAt: createdAt,
    );
    final repository = _EventRepository([event]);
    final sessions = _SessionRepository([
      Session(
        id: 'session-1',
        eventId: 'event-1',
        title: 'Original Report',
        sessionDate: DateTime(2025, 1, 2),
        records: const [],
        createdAt: createdAt,
        updatedAt: createdAt,
        createdBy: 'tester',
      ),
    ]);

    await tester.pumpWidget(
      _wrap(
        AddEventPage(
          eventRepository: repository,
          sessionRepository: sessions,
          eventToEdit: event,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Event'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete Event'), findsOneWidget);
    expect(find.textContaining('WARNING'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repository.deleteCount, 1);
  });
}
