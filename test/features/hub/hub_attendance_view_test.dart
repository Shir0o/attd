import 'dart:async';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/hub/presentation/hub_attendance_view.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAttendanceRepository implements AttendanceRepository {
  List<Family> families = [];
  int fetchCount = 0;

  @override
  Future<List<Family>> fetchFamilies() async {
    fetchCount++;
    return families;
  }

  @override
  Future<void> saveFamilies(List<Family> families) async {
    this.families = families;
  }

  @override
  Future<Family> addFamily(String displayName) async {
    throw UnimplementedError();
  }

  @override
  Future<Family> addMember(String familyId, Member member) async {
    throw UnimplementedError();
  }

  @override
  Stream<List<Family>> streamFamilies() => Stream.value(families);

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class FakeEventRepository implements EventRepository {
  final controller = StreamController<List<Event>>.broadcast();
  final deletedEventIds = <String>[];

  void emit(List<Event> events) => controller.add(events);

  @override
  Future<void> createEvent(Event event) async {}

  @override
  Future<void> updateEvent(Event event) async {}

  @override
  Future<void> deleteEvent(String eventId) async {
    deletedEventIds.add(eventId);
  }

  @override
  Future<Event?> findEventById(String eventId) async => null;

  @override
  Stream<List<Event>> streamEvents() => controller.stream;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  void dispose() {
    controller.close();
  }
}

class FakeSessionRepository implements SessionRepository {
  List<Session> sessions = [];
  final createdSessions = <Session>[];
  final deletedSessionIds = <String>[];
  int loadCount = 0;

  @override
  Future<List<Session>> loadSessions() async {
    loadCount++;
    return sessions;
  }

  @override
  Stream<List<Session>> streamSessions() => Stream.value(sessions);

  @override
  Future<Session?> findSessionById(String id) async {
    for (final session in sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  @override
  Future<Session> createSession({
    required String title,
    String? eventId,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async {
    final session = Session(
      id: 'created-${createdSessions.length + 1}',
      title: title,
      eventId: eventId,
      sessionDate: sessionDate,
      records: records,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: actor,
      currentVersion: 1,
    );
    createdSessions.add(session);
    return session;
  }

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    return session;
  }

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {
    deletedSessionIds.add(sessionId);
  }

  @override
  Future<List<SessionVersion>> history(String sessionId) async => [];

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

void main() {
  late ThemeController themeController;
  late FakeAttendanceRepository attendanceRepository;
  late FakeEventRepository eventRepository;
  late FakeSessionRepository sessionRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    themeController = ThemeController(prefs);
    attendanceRepository = FakeAttendanceRepository();
    eventRepository = FakeEventRepository();
    sessionRepository = FakeSessionRepository();
  });

  tearDown(() {
    eventRepository.dispose();
  });

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HubAttendanceView(
          themeController: themeController,
          sessionRepository: sessionRepository,
          eventRepository: eventRepository,
          attendanceRepository: attendanceRepository,
          disableAnimations: true,
        ),
      ),
    );
  }

  Event todayEvent({List<String> memberIds = const []}) {
    final now = DateTime.now();
    return Event(
      id: 'event-1',
      title: 'Sunday Service',
      time: const TimeOfDay(hour: 9, minute: 30),
      frequency: 'Weekly',
      repeatingDays: [DateFormat('EEEE').format(now)],
      memberIds: memberIds,
      createdAt: now,
    );
  }

  testWidgets('renders empty state after loading events', (tester) async {
    await pumpView(tester);

    eventRepository.emit([]);
    await tester.pumpAndSettle();

    expect(find.text('No events scheduled'), findsOneWidget);
    expect(attendanceRepository.fetchCount, 1);
    expect(sessionRepository.loadCount, greaterThanOrEqualTo(2));
  });

  testWidgets('pull to refresh reloads families and resubscribes to events', (
    tester,
  ) async {
    await pumpView(tester);
    eventRepository.emit([]);
    await tester.pumpAndSettle();

    final initialFetchCount = attendanceRepository.fetchCount;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(attendanceRepository.fetchCount, greaterThan(initialFetchCount));

    eventRepository.emit([]);
    await tester.pumpAndSettle();
    expect(find.text('No events scheduled'), findsOneWidget);
  });

  testWidgets('deleting an event from the action menu calls repository', (
    tester,
  ) async {
    await pumpView(tester);
    eventRepository.emit([todayEvent()]);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(eventRepository.deletedEventIds, ['event-1']);
  });

  testWidgets('start attendance with no event members opens member management',
      (
    tester,
  ) async {
    await pumpView(tester);
    eventRepository.emit([todayEvent()]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sunday Service'));
    await tester.pumpAndSettle();

    expect(sessionRepository.createdSessions, isEmpty);
    expect(
      find.text('Please add members to the event before starting attendance.'),
      findsOneWidget,
    );
    expect(find.text('Manage Event Members'), findsOneWidget);
  });

  testWidgets('start attendance with event members creates a session', (
    tester,
  ) async {
    attendanceRepository.families = [
      Family(
        id: 'family-1',
        displayName: 'Family 1',
        members: [Member(id: 'member-1', displayName: 'Alice')],
        updatedAt: DateTime.now(),
      ),
    ];

    await pumpView(tester);
    eventRepository.emit([
      todayEvent(memberIds: ['member-1'])
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sunday Service'));
    await tester.pumpAndSettle();

    expect(sessionRepository.createdSessions, hasLength(1));
    expect(sessionRepository.createdSessions.single.title, 'Sunday Service');
    expect(sessionRepository.createdSessions.single.eventId, 'event-1');
  });
}
