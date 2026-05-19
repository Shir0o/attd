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
  Object? createError;
  Object? updateError;
  Object? deleteError;
  int createCount = 0;
  int updateCount = 0;
  int deleteCount = 0;

  _EventRepository([List<Event>? initial]) : events = [...?initial];

  @override
  Future<void> createEvent(Event event) async {
    createCount++;
    if (createError != null) {
      throw createError!;
    }
    events.add(event);
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    deleteCount++;
    if (deleteError != null) {
      throw deleteError!;
    }
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
    if (updateError != null) {
      throw updateError!;
    }
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
  Future<Session> saveSnapshot(Session session,
          {required String actor}) async =>
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

  testWidgets('creates a one-time event', (tester) async {
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

    await tester.enterText(find.byType(TextFormField), 'Workshop');
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('One-time').last);
    await tester.pumpAndSettle();

    expect(find.text('Date'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save_event_button')));
    await tester.pumpAndSettle();

    expect(repository.createCount, 1);
    expect(repository.events.single.frequency, 'One-time');
    expect(repository.events.single.oneTimeDate, isNotNull);
    expect(repository.events.single.repeatingDays, isEmpty);
  });

  testWidgets('edits an existing event and preserves identifiers', (
    tester,
  ) async {
    final createdAt = DateTime(2025, 1, 1);
    final event = Event(
      id: 'event-1',
      title: 'Original',
      time: const TimeOfDay(hour: 9, minute: 30),
      frequency: 'Weekly',
      repeatingDays: const ['Sunday'],
      memberIds: const ['member-1'],
      createdAt: createdAt,
    );
    final repository = _EventRepository([event]);

    await tester.pumpWidget(
      _wrap(
        AddEventPage(
          eventRepository: repository,
          eventToEdit: event,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Updated Event');
    await tester.tap(find.byKey(const ValueKey('save_event_button')));
    await tester.pumpAndSettle();

    expect(repository.updateCount, 1);
    expect(repository.events.single.id, 'event-1');
    expect(repository.events.single.title, 'Updated Event');
    expect(repository.events.single.memberIds, ['member-1']);
    expect(repository.events.single.createdAt, createdAt);
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

  testWidgets('shows a snackbar when saving fails', (tester) async {
    final repository = _EventRepository()..createError = StateError('boom');

    await tester.pumpWidget(
      _wrap(
        AddEventPage(
          eventRepository: repository,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Broken Event');
    await tester.tap(find.byKey(const ValueKey('save_event_button')));
    await tester.pump();

    expect(repository.createCount, 1);
    expect(find.textContaining('Error saving event'), findsOneWidget);
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

  testWidgets('canceling delete keeps the event', (tester) async {
    final createdAt = DateTime(2025, 1, 1);
    final event = Event(
      id: 'event-1',
      title: 'Original',
      time: const TimeOfDay(hour: 9, minute: 30),
      frequency: 'Monthly',
      createdAt: createdAt,
    );
    final repository = _EventRepository([event]);

    await tester.pumpWidget(
      _wrap(
        AddEventPage(
          eventRepository: repository,
          eventToEdit: event,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.deleteCount, 0);
    expect(repository.events.single.id, 'event-1');
    expect(find.text('Edit Event'), findsOneWidget);
  });

  testWidgets('tapping the event time field opens a time picker',
      (tester) async {
    final repository = _EventRepository();

    await tester.pumpWidget(_wrap(
      AddEventPage(
        eventRepository: repository,
        disableAnimations: true,
      ),
    ));
    await tester.pumpAndSettle();

    // Tap the time row, identified by the schedule icon.
    await tester.tap(find.byIcon(Icons.schedule));
    await tester.pumpAndSettle();

    // Material time picker renders Cancel and a confirm action.
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('tapping the date field in one-time mode opens a date picker',
      (tester) async {
    final repository = _EventRepository();

    await tester.pumpWidget(_wrap(
      AddEventPage(
        eventRepository: repository,
        disableAnimations: true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('One-time').last);
    await tester.pumpAndSettle();

    // The InputDecorator wrapping the Date field is the third one in the form.
    final decorators = find.byType(InputDecorator);
    await tester.tap(decorators.last);
    await tester.pumpAndSettle();

    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('weekday chips toggle on tap', (tester) async {
    // Seed with a known event so the initial state is deterministic
    // (Wednesday selected). Tapping Wednesday should remove it; tapping
    // Friday should add it.
    final event = Event(
      id: 'event-1',
      title: 'Toggle',
      time: const TimeOfDay(hour: 9, minute: 0),
      frequency: 'Weekly',
      repeatingDays: const ['Wednesday'],
      createdAt: DateTime(2025, 1, 1),
    );
    final repository = _EventRepository([event]);

    await tester.pumpWidget(_wrap(
      AddEventPage(
        eventRepository: repository,
        eventToEdit: event,
        disableAnimations: true,
      ),
    ));
    await tester.pumpAndSettle();

    // The weekday chips are 44x44 GestureDetectors; locate them by their
    // single-letter labels. "W" appears once (Wednesday).
    await tester.tap(find.text('W'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('F'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('save_event_button')));
    await tester.pumpAndSettle();

    expect(repository.events.single.repeatingDays, ['Friday']);
  });

  testWidgets('save button renders inside a Hero when animations are enabled',
      (tester) async {
    final repository = _EventRepository();

    await tester.pumpWidget(_wrap(
      AddEventPage(
        eventRepository: repository,
        // disableAnimations omitted, defaults to false -> Hero path.
      ),
    ));
    // Animations enabled, so wait out the 800ms minimum loading window
    // before tapping save.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(Hero), findsWidgets);
    expect(find.byKey(const ValueKey('save_event_button')), findsOneWidget);
  });

  testWidgets('shows a snackbar when deleting fails', (tester) async {
    final createdAt = DateTime(2025, 1, 1);
    final event = Event(
      id: 'event-1',
      title: 'Original',
      time: const TimeOfDay(hour: 9, minute: 30),
      frequency: 'Monthly',
      createdAt: createdAt,
    );
    final repository = _EventRepository([event])
      ..deleteError = StateError('delete failed');

    await tester.pumpWidget(
      _wrap(
        AddEventPage(
          eventRepository: repository,
          eventToEdit: event,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pump();

    expect(repository.deleteCount, 1);
    expect(find.textContaining('Error deleting event'), findsOneWidget);
  });
}
