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
import 'package:attendance_tracker/core/design/app_shimmer.dart';

import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';

class MockAttendanceRepository extends AttendanceRepository {
  @override
  Future<List<Family>> fetchFamilies() async => [];

  @override
  Future<void> saveFamilies(List<Family> families) async {}

  @override
  Future<Family> addMember(String familyId, Member member) async {
    throw UnimplementedError();
  }

  @override
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Stream<List<Family>> streamFamilies() {
    return Stream.value([]);
  }
}

class MockEventRepository implements EventRepository {
  final _controller = StreamController<List<Event>>.broadcast();

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
  Future<Event?> findEventById(String eventId) async => null;

  @override
  Stream<List<Event>> streamEvents() {
    return _controller.stream;
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class MockSessionRepository implements SessionRepository {
  @override
  Stream<List<Session>> streamSessions() {
    return Stream.value([]);
  }

  @override
  Future<Session> createSession({
    required String title,
    String? eventId,
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
  Future<List<Session>> loadSessions() async => [];

  @override
  Future<Session?> findSessionById(String id) async => null;

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    return session;
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
  Future<void> deleteSession(String sessionId, {required String actor}) async {}

  @override
  Future<List<SessionVersion>> history(String sessionId) async {
    return [];
  }

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

void main() {
  late ThemeController themeController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    themeController = ThemeController(prefs);
  });

  testWidgets('HubPage displays events sorted by Today', (
    WidgetTester tester,
  ) async {
    final mockEventRepo = MockEventRepository();
    final mockSessionRepo = MockSessionRepository();
    final mockAttendanceRepo = MockAttendanceRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: TickerMode(
          enabled: false,
          child: HubPage(
            themeController: themeController,
            sessionRepository: mockSessionRepo,
            eventRepository: mockEventRepo,
            attendanceRepository: mockAttendanceRepo,
            disableAnimations: true,
          ),
        ),
      ),
    );

    // Initial state
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

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

    // Verify "TODAY" tag on today's event (the hero "TODAY · time" pill).
    expect(find.textContaining('TODAY'), findsOneWidget);

    // Verify Order: Today Event should be first in the list
    final todayTextFinder = find.text('Today Event');
    final futureTextFinder = find.text('Future Event');

    final todayPosition = tester.getTopLeft(todayTextFinder).dy;
    final futurePosition = tester.getTopLeft(futureTextFinder).dy;

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

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: TickerMode(
            enabled: false,
            child: HubPage(
              themeController: themeController,
              sessionRepository: mockSessionRepo,
              eventRepository: mockEventRepo,
              attendanceRepository: mockAttendanceRepo,
              disableAnimations: true,
            ),
          ),
        ),
      ),
    );

    // Initial state check - verify it renders AppShimmer
    expect(find.byType(AppShimmer), findsWidgets);

    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

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

    // Check for overflow errors
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
        home: TickerMode(
          enabled: false,
          child: HubPage(
            themeController: themeController,
            sessionRepository: mockSessionRepo,
            eventRepository: mockEventRepo,
            attendanceRepository: mockAttendanceRepo,
            disableAnimations: true,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

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

    mockEventRepo.emit([eventToday]);
    await tester.pumpAndSettle();

    final menuButton = find.byIcon(Icons.more_vert);
    expect(menuButton, findsOneWidget);

    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    final manageMembersOption = find.text('Manage Members');
    expect(manageMembersOption, findsOneWidget);

    await tester.tap(manageMembersOption);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('member_add_fab')), findsOneWidget);
  });
}
