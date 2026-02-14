import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/hub/presentation/hub_page.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:intl/intl.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_version.dart';

import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';

class MockAttendanceRepository implements AttendanceRepository {
  @override
  Future<List<Family>> fetchFamilies() async => [];

  @override
  Future<void> saveFamilies(List<Family> families) async {}

  @override
  Future<Family> addMember(String familyId, Member member) async {
    throw UnimplementedError();
  }

  @override
  Future<Family> addFamily(String displayName) async {
    throw UnimplementedError();
  }
}

class MockEventRepository implements EventRepository {
  final _controller = StreamController<List<Event>>();

  void emit(List<Event> events) {
    _controller.add(events);
  }

  @override
  Future<void> createEvent(Event event) async {}

  @override
  Future<void> updateEvent(Event event) async {}

  @override
  Future<void> deleteEvent(String eventId) async {}

  @override
  Stream<List<Event>> streamEvents() {
    return _controller.stream;
  }
}

class MockSessionRepository implements SessionRepository {
  @override
  Future<Session> createSession({
    required String title,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async {
    return Session(
      id: 'mock-id',
      title: title,
      sessionDate: sessionDate,
      records: records,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: actor,
      currentVersion: 1,
    );
  }

  @override
  Future<List<Session>> loadSessions({bool includeDeleted = false}) async => [];

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    return session;
  }

  @override
  Future<Session?> revertToPrevious(
    String sessionId, {
    required String actor,
  }) async {
    return null;
  }

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async {
    return Session(
      id: 'dup-id',
      title: 'Duplicate',
      sessionDate: DateTime.now(),
      records: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: actor,
      currentVersion: 1,
    );
  }

  @override
  Future<List<SessionVersion>> history(String sessionId) async {
    return [];
  }
}

void main() {
  testWidgets('HubPage displays events sorted by Today', (
    WidgetTester tester,
  ) async {
    final mockEventRepo = MockEventRepository();
    final mockSessionRepo = MockSessionRepository();
    final mockAttendanceRepo = MockAttendanceRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HubPage(
          sessionRepository: mockSessionRepo,
          eventRepository: mockEventRepo,
          attendanceRepository: mockAttendanceRepo,
        ),
      ),
    );

    // Initial state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final now = DateTime.now();
    final todayWeekday = DateFormat('EEEE').format(now);
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowWeekday = DateFormat('EEEE').format(tomorrow);

    final eventToday = Event(
      id: '1',
      title: 'Today Event',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'Weekly',
      repeatingDays: [todayWeekday],
      createdAt: now,
    );

    final eventNotToday = Event(
      id: '2',
      title: 'Future Event',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'Weekly',
      repeatingDays: [tomorrowWeekday],
      createdAt: now,
    );

    // Emit events
    mockEventRepo.emit([eventNotToday, eventToday]); // Emit unsorted

    await tester.pumpAndSettle();

    // Verify both are present
    expect(find.text('Today Event'), findsOneWidget);
    expect(find.text('Future Event'), findsOneWidget);

    // Verify "TODAY" tag on today's event
    // Note: 'TODAY' appears in AppBar AND on the event card.
    expect(find.text('TODAY'), findsAtLeastNWidgets(2));

    // Verify Order: Today Event should be first in the list
    final todayTextFinder = find.text('Today Event');
    final futureTextFinder = find.text('Future Event');

    // Find the Card wrapping the text
    final todayCardFinder = find.ancestor(
      of: todayTextFinder,
      matching: find.byType(Card),
    );
    final futureCardFinder = find.ancestor(
      of: futureTextFinder,
      matching: find.byType(Card),
    );

    // Proceed only if exactly 1 found
    if (todayCardFinder.evaluate().length != 1 ||
        futureCardFinder.evaluate().length != 1) {
      // Let it fail naturally later or return early
    }

    final todayPosition = tester.getTopLeft(todayCardFinder).dy;
    final futurePosition = tester.getTopLeft(futureCardFinder).dy;

    expect(
      todayPosition,
      lessThan(futurePosition),
      reason: 'Today events should appear before future events',
    );
  });

  testWidgets('HubPage handles large text scale factor without overflow', (
    WidgetTester tester,
  ) async {
    final mockEventRepo = MockEventRepository();
    final mockSessionRepo = MockSessionRepository();
    final mockAttendanceRepo = MockAttendanceRepository();

    // Set a large text scale factor using platformDispatcher
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;

    await tester.pumpWidget(
      MaterialApp(
        home: HubPage(
          sessionRepository: mockSessionRepo,
          eventRepository: mockEventRepo,
          attendanceRepository: mockAttendanceRepo,
        ),
      ),
    );

    // Initial state check - verify it renders at all
    await tester.pump();

    final now = DateTime.now();
    final todayWeekday = DateFormat('EEEE').format(now);

    final eventToday = Event(
      id: '1',
      title: 'Very Long Title That Might Overflow When Text Scale Is Huge',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'Weekly',
      repeatingDays: [todayWeekday],
      createdAt: now,
    );

    mockEventRepo.emit([eventToday]);
    await tester.pumpAndSettle();

    // Check for overflow errors by ensuring no exception was thrown
    expect(tester.takeException(), isNull);
  });

  testWidgets('Can navigate to Manage Members from event menu', (
    WidgetTester tester,
  ) async {
    final mockEventRepo = MockEventRepository();
    final mockSessionRepo = MockSessionRepository();
    final mockAttendanceRepo = MockAttendanceRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HubPage(
          sessionRepository: mockSessionRepo,
          eventRepository: mockEventRepo,
          attendanceRepository: mockAttendanceRepo,
        ),
      ),
    );

    // Initial state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final now = DateTime.now();
    final todayWeekday = DateFormat('EEEE').format(now);

    final eventToday = Event(
      id: '1',
      title: 'Test Event',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'Weekly',
      repeatingDays: [todayWeekday],
      createdAt: now,
    );

    // Emit event
    mockEventRepo.emit([eventToday]);
    await tester.pumpAndSettle();

    // Find menu button (icon is Icons.more_vert)
    final menuButton = find.byIcon(Icons.more_vert);
    expect(menuButton, findsOneWidget);

    // Tap menu
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    // Verify 'Manage Members' option is present
    final manageMembersOption = find.text('Manage Members');
    expect(manageMembersOption, findsOneWidget);

    // Tap 'Manage Members'
    await tester.tap(manageMembersOption);
    await tester.pumpAndSettle();

    // Verify we are on MembersPage (it has a title 'Manage Members')
    expect(find.text('Manage Members'), findsOneWidget);
    // And an 'Add member' button (floating action button or similar)
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
