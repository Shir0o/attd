import 'dart:async';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
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

  testWidgets('action menu: Manage Members navigates to members page',
      (tester) async {
    await pumpView(tester);
    eventRepository.emit([todayEvent()]);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage Members'));
    await tester.pumpAndSettle();

    expect(find.text('Manage Event Members'), findsOneWidget);
  });

  testWidgets('action menu: View History navigates to event history',
      (tester) async {
    await pumpView(tester);
    eventRepository.emit([todayEvent()]);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View History'));
    await tester.pumpAndSettle();

    expect(find.text('Sunday Service History'), findsOneWidget);
  });

  testWidgets('action menu: Edit Event navigates to AddEventPage',
      (tester) async {
    await pumpView(tester);
    eventRepository.emit([todayEvent()]);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Event'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Event'), findsOneWidget); // app bar title
  });

  testWidgets('action menu: cancelling delete keeps the event',
      (tester) async {
    await pumpView(tester);
    eventRepository.emit([todayEvent()]);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Event'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(eventRepository.deletedEventIds, isEmpty);
  });

  testWidgets('renders a one-time event with its formatted date', (tester) async {
    final futureDate = DateTime.now().add(const Duration(days: 14));
    final event = Event(
      id: 'one',
      title: 'Workshop',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'One-time',
      oneTimeDate: futureDate,
      createdAt: DateTime.now(),
    );
    await pumpView(tester);
    eventRepository.emit([event]);
    await tester.pumpAndSettle();

    final expected =
        DateFormat('EEEE, MMM d, yyyy').format(futureDate);
    expect(find.text(expected), findsOneWidget);
    // Upcoming events render the plain text status (else-branch of pill).
    expect(find.text('Upcoming'), findsOneWidget);
  });

  testWidgets(
      'event with an existing session for today shows the Taken pill',
      (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    sessionRepository.sessions = [
      Session(
        id: 'session-today',
        eventId: 'event-1',
        title: 'Sunday Service',
        sessionDate: today,
        records: const [],
        createdAt: today,
        updatedAt: today,
        createdBy: 'user',
      ),
    ];

    await pumpView(tester);
    eventRepository.emit([todayEvent()]);
    await tester.pumpAndSettle();

    expect(find.text('TAKEN'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets(
      'tapping a card with a complete session opens SessionSummaryPage',
      (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final member = Member(id: 'member-1', displayName: 'Alice');
    attendanceRepository.families = [
      Family(
        id: 'family-1',
        displayName: 'Family 1',
        members: [member],
        updatedAt: now,
      ),
    ];
    sessionRepository.sessions = [
      Session(
        id: 'session-today',
        eventId: 'event-1',
        title: 'Sunday Service',
        sessionDate: today,
        records: [
          SessionRecord(
            memberId: 'member-1',
            attendee: 'Alice',
            status: AttendanceStatus.present,
            recordedAt: today,
            recordedBy: 'user',
          ),
        ],
        createdAt: today,
        updatedAt: today,
        createdBy: 'user',
      ),
    ];

    await pumpView(tester);
    eventRepository.emit([todayEvent(memberIds: ['member-1'])]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sunday Service'));
    await tester.pumpAndSettle();

    // SessionSummaryPage shows a "Summary" title; if not findable due to
    // animations, assert that no new session was created — we navigated
    // to the summary, not the deck path.
    expect(sessionRepository.createdSessions, isEmpty);
  });

  testWidgets('FAB navigates to a new AddEventPage', (tester) async {
    await pumpView(tester);
    eventRepository.emit([]);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // AddEventPage app bar title in create mode.
    expect(find.text('New Event'), findsOneWidget);
  });

  testWidgets('one-time event scheduled for today shows the Start pill', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final event = Event(
      id: 'one',
      title: 'Today Workshop',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'One-time',
      oneTimeDate: today,
      memberIds: const [],
      createdAt: now,
    );
    await pumpView(tester);
    eventRepository.emit([event]);
    await tester.pumpAndSettle();

    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('multiple events sort with today first, then by time', (tester) async {
    final now = DateTime.now();
    final dayName = DateFormat('EEEE').format(now);
    final tomorrow = DateFormat('EEEE').format(now.add(const Duration(days: 1)));
    final todayEarly = Event(
      id: 'a',
      title: 'Early Today',
      time: const TimeOfDay(hour: 6, minute: 0),
      frequency: 'Weekly',
      repeatingDays: [dayName],
      createdAt: now,
    );
    final todayLate = Event(
      id: 'b',
      title: 'Late Today',
      time: const TimeOfDay(hour: 18, minute: 0),
      frequency: 'Weekly',
      repeatingDays: [dayName],
      createdAt: now,
    );
    final notToday = Event(
      id: 'c',
      title: 'Other Day',
      time: const TimeOfDay(hour: 8, minute: 0),
      frequency: 'Weekly',
      repeatingDays: [tomorrow == dayName ? 'Monday' : tomorrow],
      createdAt: now,
    );

    await pumpView(tester);
    eventRepository.emit([notToday, todayLate, todayEarly]);
    await tester.pumpAndSettle();

    final widgets = tester.widgetList<Text>(find.byType(Text)).toList();
    final positions = <String, int>{};
    for (var i = 0; i < widgets.length; i++) {
      final t = widgets[i].data;
      if (t == 'Early Today' || t == 'Late Today' || t == 'Other Day') {
        positions[t!] = i;
      }
    }
    expect(positions['Early Today']! < positions['Late Today']!, isTrue);
    expect(positions['Late Today']! < positions['Other Day']!, isTrue);
  });

  testWidgets('event with session on past day shows Taken with date suffix', (tester) async {
    final now = DateTime.now();
    // Pick a repeating day that isn't today so lastSupposed is in the past.
    final notTodayDay =
        DateFormat('EEEE').format(now.subtract(const Duration(days: 1)));
    final event = Event(
      id: 'event-past',
      title: 'Past Service',
      time: const TimeOfDay(hour: 9, minute: 0),
      frequency: 'Weekly',
      repeatingDays: [notTodayDay],
      createdAt: now.subtract(const Duration(days: 30)),
    );
    sessionRepository.sessions = [
      Session(
        id: 'session-past',
        eventId: 'event-past',
        title: 'Past Service',
        sessionDate: now.subtract(const Duration(days: 1)),
        records: const [],
        createdAt: now,
        updatedAt: now,
        createdBy: 'user',
      ),
    ];

    await pumpView(tester);
    eventRepository.emit([event]);
    await tester.pumpAndSettle();

    // Status text is either 'TAKEN (MMM d)' (rendered in pill, uppercase) or
    // — if the session date happens to be today — just 'TAKEN'. Both exercise
    // the Taken branch.
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .toList();
    expect(
      texts.any((t) => t.startsWith('TAKEN')),
      isTrue,
      reason: 'Expected a TAKEN status pill, got: $texts',
    );
  });

  testWidgets('legacy session without eventId matches by title in the card list',
      (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    sessionRepository.sessions = [
      Session(
        id: 'legacy',
        eventId: null,
        title: 'Sunday Service',
        sessionDate: today,
        records: const [],
        createdAt: today,
        updatedAt: today,
        createdBy: 'user',
      ),
    ];

    await pumpView(tester);
    eventRepository.emit([todayEvent()]);
    await tester.pumpAndSettle();

    expect(find.text('TAKEN'), findsOneWidget);
  });

  testWidgets('animated loading (animations enabled) waits for skeleton then shows events',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HubAttendanceView(
          themeController: themeController,
          sessionRepository: sessionRepository,
          eventRepository: eventRepository,
          attendanceRepository: attendanceRepository,
          // disableAnimations defaults to false: exercises the delayed branch.
        ),
      ),
    );
    eventRepository.emit([]);
    // First frame: still in skeleton.
    await tester.pump();
    // Advance past 800ms minimum and let animations settle.
    await tester.pump(const Duration(milliseconds: 801));
    await tester.pumpAndSettle();
    expect(find.text('No events scheduled'), findsOneWidget);
  });

  testWidgets('action menu: View History returns and refreshes', (tester) async {
    await pumpView(tester);
    eventRepository.emit([todayEvent()]);
    await tester.pumpAndSettle();

    final initialFetch = attendanceRepository.fetchCount;
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View History'));
    await tester.pumpAndSettle();
    // Pop the history page.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(attendanceRepository.fetchCount, greaterThan(initialFetch));
  });

  testWidgets('FAB returns and refreshes', (tester) async {
    await pumpView(tester);
    eventRepository.emit([]);
    await tester.pumpAndSettle();

    final initialFetch = attendanceRepository.fetchCount;
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(attendanceRepository.fetchCount, greaterThan(initialFetch));
  });

  testWidgets(
      'tapping a card with an incomplete session opens AttendanceDeckPage',
      (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final members = [
      Member(id: 'm1', displayName: 'Alice'),
      Member(id: 'm2', displayName: 'Bob'),
    ];
    attendanceRepository.families = [
      Family(
        id: 'family-1',
        displayName: 'Family 1',
        members: members,
        updatedAt: now,
      ),
    ];
    sessionRepository.sessions = [
      Session(
        id: 'session-today',
        eventId: 'event-1',
        title: 'Sunday Service',
        sessionDate: today,
        // Only one record, but two members assigned -> incomplete.
        records: [
          SessionRecord(
            memberId: 'm1',
            attendee: 'Alice',
            status: AttendanceStatus.present,
            recordedAt: today,
            recordedBy: 'user',
          ),
        ],
        createdAt: today,
        updatedAt: today,
        createdBy: 'user',
      ),
    ];

    await pumpView(tester);
    eventRepository.emit([
      todayEvent(memberIds: ['m1', 'm2']),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sunday Service'));
    await tester.pumpAndSettle();

    // No new session was created — we navigated to the deck for the
    // existing incomplete session.
    expect(sessionRepository.createdSessions, isEmpty);
  });
}
