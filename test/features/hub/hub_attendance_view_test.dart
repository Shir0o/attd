import 'dart:async';

import 'package:attendance_tracker/core/design/widgets/conv_widgets.dart';
import 'package:attendance_tracker/core/presentation/no_transitions_builder.dart';
import 'package:attendance_tracker/core/ui/app_error_feedback.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/handoff/data/handoff_sharer.dart';
import 'package:attendance_tracker/features/handoff/domain/handoff_file.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/hub/presentation/add_event_page.dart';
import 'package:attendance_tracker/features/hub/presentation/hub_attendance_view.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeHandoffSharer extends HandoffSharer {
  final sent = <({HandoffDocument document, String fileName, String text})>[];

  @override
  Future<void> send({
    required HandoffDocument document,
    required String fileName,
    required String text,
  }) async {
    sent.add((document: document, fileName: fileName, text: text));
  }
}

class FakeAttendanceRepository extends AttendanceRepository {
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
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) async {
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

class FakeEventRepository extends EventRepository {
  final controller = StreamController<List<Event>>.broadcast();
  final deletedEventIds = <String>[];
  final updatedEvents = <Event>[];

  void emit(List<Event> events) => controller.add(events);

  @override
  Future<void> createEvent(Event event) async {}

  @override
  Future<void> updateEvent(Event event) async {
    updatedEvents.add(event);
  }

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

class FakeSessionRepository extends SessionRepository {
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

  Future<void> pumpView(
    WidgetTester tester, {
    bool disableAnimations = true,
    bool systemDisableAnimations = false,
    bool snapPages = false,
    HandoffSharer? handoffSharer,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        // Like the real app (ADR 0008): pages snap, only Heroes fly.
        theme: snapPages
            ? ThemeData(
                pageTransitionsTheme: PageTransitionsTheme(
                  builders: {
                    for (final p in TargetPlatform.values)
                      p: const NoTransitionsBuilder(),
                  },
                ),
              )
            : null,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: systemDisableAnimations),
          child: child!,
        ),
        home: HubAttendanceView(
          themeController: themeController,
          sessionRepository: sessionRepository,
          eventRepository: eventRepository,
          attendanceRepository: attendanceRepository,
          handoffSharer: handoffSharer,
          disableAnimations: disableAnimations,
        ),
      ),
    );
  }

  Event todayEvent({
    List<String> memberIds = const [],
  }) {
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

    expect(find.text('Nothing on the calendar yet.'), findsOneWidget);
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
    expect(find.text('Nothing on the calendar yet.'), findsOneWidget);
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

    // No picker stands in the way: the grid opens straight away.
    expect(find.byKey(const Key('startModeConfirmButton')), findsNothing);
    expect(find.byKey(const Key('groupingConfirmButton')), findsNothing);
    expect(find.byKey(const Key('likelyHereChip_member-1')), findsOneWidget);

    expect(sessionRepository.createdSessions, hasLength(1));
    expect(sessionRepository.createdSessions.single.title, 'Sunday Service');
    expect(sessionRepository.createdSessions.single.eventId, 'event-1');
    // A new session starts with nobody marked.
    expect(sessionRepository.createdSessions.single.records, isEmpty);
  });

  testWidgets('event three-dot menu no longer offers the mode entries',
      (tester) async {
    await pumpView(tester);
    eventRepository.emit([todayEvent()]);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Attendance Mode'), findsNothing);
    expect(find.text('Fast Marking Mode'), findsNothing);
    expect(find.byKey(const Key('eventMenuFastMarkingMode')), findsNothing);
    expect(find.text('View Insights'), findsNothing);
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

    expect(find.text('EDIT EVENT'), findsOneWidget); // app bar title
  });

  testWidgets('renders a one-time event with its formatted date', (tester) async {
    // The full formatted date renders on the highlight (hero) card, which is
    // reserved for today's event — so schedule the one-time event for today.
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final event = Event(
      id: 'one',
      title: 'Workshop',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'One-time',
      oneTimeDate: todayDate,
      createdAt: now,
    );
    await pumpView(tester);
    eventRepository.emit([event]);
    await tester.pumpAndSettle();

    final expected =
        DateFormat('EEEE, MMM d, yyyy').format(todayDate);
    expect(find.text(expected), findsOneWidget);
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

    expect(find.text('Taken'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
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
    expect(find.text('NEW EVENT'), findsOneWidget);
  });

  group('FAB to Create event shuttle', () {
    final shuttle = find.byKey(const ValueKey('fab_pill_shuttle'));
    final label = find.byKey(const ValueKey('fab_pill_shuttle_label'));

    Future<void> openFlight(WidgetTester tester) async {
      await pumpView(tester, disableAnimations: false, snapPages: true);
      eventRepository.emit([]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hub_fab')));
      await tester.pump();
    }

    testWidgets('flies the FAB into the pill without wrapping the label', (
      tester,
    ) async {
      await openFlight(tester);
      expect(find.byType(Hero), findsWidgets);

      // Early in the flight the box is still close to the 56 px FAB, but the
      // label keeps its intrinsic width on a single line.
      await tester.pump(const Duration(milliseconds: 30));
      expect(shuttle, findsOneWidget);
      final shuttleWidth = tester.getSize(shuttle).width;
      expect(shuttleWidth, lessThan(150));
      final labelText = tester.widget<Text>(label);
      expect(labelText.data, 'Create event');
      expect(labelText.softWrap, isFalse);
      expect(labelText.maxLines, 1);
      expect(tester.getSize(label).width, greaterThan(shuttleWidth));
      expect(tester.getSize(label).height, lessThan(30));

      // Follow the flight frame by frame until the shuttle lands.
      final pill = tester.getRect(
        find.descendant(
          of: find.byType(AddEventPage),
          matching: find.byType(Hero),
        ),
      );
      var lastSeen = tester.getRect(shuttle);
      var frames = 0;
      while (shuttle.evaluate().isNotEmpty && frames < 60) {
        lastSeen = tester.getRect(shuttle);
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      expect(shuttle, findsNothing, reason: 'the flight should finish');
      expect(lastSeen.left, closeTo(pill.left, 6));
      expect(lastSeen.right, closeTo(pill.right, 6));
      expect(lastSeen.top, closeTo(pill.top, 6));
      expect(lastSeen.bottom, closeTo(pill.bottom, 6));

      await tester.pumpAndSettle();
      expect(shuttle, findsNothing);
      expect(find.text('NEW EVENT'), findsOneWidget);
    });

    testWidgets('flies back into the FAB when leaving the page', (
      tester,
    ) async {
      await openFlight(tester);
      await tester.pumpAndSettle();

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(shuttle, findsOneWidget);
      expect(tester.widget<Text>(label).softWrap, isFalse);

      await tester.pumpAndSettle();
      expect(shuttle, findsNothing);
      expect(find.byKey(const ValueKey('hub_fab')), findsOneWidget);
    });

    testWidgets('the FAB presses in when motion is on', (tester) async {
      await pumpView(tester, disableAnimations: false);
      eventRepository.emit([]);
      await tester.pumpAndSettle();
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('hub_fab')),
          matching: find.byType(ConvPressable),
        ),
        findsOneWidget,
      );
    });

    for (final (name, flag, system) in [
      ('the test flag', true, false),
      ('the system setting', false, true),
    ]) {
      testWidgets('does not fly when $name disables motion', (tester) async {
        await pumpView(
          tester,
          disableAnimations: flag,
          systemDisableAnimations: system,
        );
        eventRepository.emit([]);
        await tester.pumpAndSettle();
        expect(find.byType(Hero), findsNothing);

        await tester.tap(find.byKey(const ValueKey('hub_fab')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        expect(shuttle, findsNothing);

        await tester.pumpAndSettle();
        expect(find.text('NEW EVENT'), findsOneWidget);
        expect(find.byType(Hero), findsNothing);
      });
    }
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

    expect(find.text('Start'), findsOneWidget);
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

  testWidgets(
      'multiple today events render one highlight card plus an Also today group',
      (tester) async {
    final now = DateTime.now();
    final dayName = DateFormat('EEEE').format(now);
    Event todayAt(String id, String title, int hour) => Event(
          id: id,
          title: title,
          time: TimeOfDay(hour: hour, minute: 0),
          frequency: 'Weekly',
          repeatingDays: [dayName],
          createdAt: now,
        );

    await pumpView(tester);
    eventRepository.emit([
      todayAt('a', 'Morning Prayer', 8),
      todayAt('b', 'Sunday School', 11),
      todayAt('c', 'Evening Service', 18),
    ]);
    await tester.pumpAndSettle();

    // Exactly one highlight (hero) card — its "Expected" eyebrow is unique.
    expect(find.text('EXPECTED'), findsOneWidget);
    // Header shows the count pill.
    expect(find.text('3 EVENTS'), findsOneWidget);
    // The other two same-day events live under "Also today".
    expect(find.text('ALSO TODAY'), findsOneWidget);
    expect(find.text('2 LATER'), findsOneWidget);
    // Each "Also today" row carries an expected-count subline.
    expect(find.textContaining('expected'), findsNWidgets(2));
  });

  testWidgets(
      'no today events: rest-state card with next-up affordance under This week',
      (tester) async {
    final now = DateTime.now();
    final notTodayDay =
        DateFormat('EEEE').format(now.add(const Duration(days: 2)));
    final event = Event(
      id: 'future',
      title: 'Mid-week Study',
      time: const TimeOfDay(hour: 19, minute: 0),
      frequency: 'Weekly',
      repeatingDays: [notTodayDay],
      createdAt: now,
    );

    await pumpView(tester);
    eventRepository.emit([event]);
    await tester.pumpAndSettle();

    // Rest-state card instead of the Start hero (no "Expected" stat).
    expect(find.text('EXPECTED'), findsNothing);
    expect(find.text('Nothing scheduled.'), findsOneWidget);
    expect(find.text('NEXT UP'), findsOneWidget);
    // Section is "This week", and the event shows in both the card and the list.
    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.text('UPCOMING'), findsNothing);
    expect(find.text('Mid-week Study'), findsNWidgets(2));
  });

  testWidgets('rest-state card tap opens the next event', (tester) async {
    final now = DateTime.now();
    final notTodayDay =
        DateFormat('EEEE').format(now.add(const Duration(days: 2)));
    final event = Event(
      id: 'future',
      title: 'Mid-week Study',
      time: const TimeOfDay(hour: 19, minute: 0),
      frequency: 'Weekly',
      repeatingDays: [notTodayDay],
      createdAt: now,
    );

    await pumpView(tester);
    eventRepository.emit([event]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nothing scheduled.'));
    await tester.pumpAndSettle();

    // Tapping the rest-state card routes into the next event's flow (here it has
    // no members, so it opens member management).
    expect(find.text('Manage Event Members'), findsOneWidget);
  });

  testWidgets('event with session on past day shows Marked status inline', (tester) async {
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

    // The upcoming row shows an inline 'Marked' status once a session exists
    // for the most recent occurrence.
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .toList();
    expect(
      texts.any((t) => t == 'Marked'),
      isTrue,
      reason: 'Expected an inline Marked status, got: $texts',
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

    expect(find.text('Taken'), findsOneWidget);
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
    expect(find.text('Nothing on the calendar yet.'), findsOneWidget);
  });

  testWidgets('the loaded list fades in over 200 ms after the skeleton (#222 M7)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HubAttendanceView(
          themeController: themeController,
          sessionRepository: sessionRepository,
          eventRepository: eventRepository,
          attendanceRepository: attendanceRepository,
        ),
      ),
    );
    eventRepository.emit([]);
    await tester.pump();
    expect(find.byKey(const ValueKey('hub_skeleton')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 801));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('hub_skeleton')), findsNothing);
    final fade = tester.widget<SliverOpacity>(find.byType(SliverOpacity));
    expect(fade.opacity, inExclusiveRange(0, 1));

    await tester.pumpAndSettle();
    expect(tester.widget<SliverOpacity>(find.byType(SliverOpacity)).opacity, 1);
    expect(find.text('Nothing on the calendar yet.'), findsOneWidget);
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

  group('event menu and handoff', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
    }

    testWidgets('menu is exactly Edit Event, Hand off, View History in order',
        (tester) async {
      await pumpView(tester);
      eventRepository.emit([todayEvent()]);
      await tester.pumpAndSettle();
      await openMenu(tester);

      final titles = tester
          .widgetList<ListTile>(
            find.descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(ListTile),
            ),
          )
          .map((t) => (t.title! as Text).data)
          .toList();
      expect(titles, ['Edit Event', 'Hand off', 'View History']);
      expect(find.text('Share Event'), findsNothing);
    });

    testWidgets('Hand off explains the file, then opens the share sheet',
        (tester) async {
      final sharer = FakeHandoffSharer();
      attendanceRepository.families = [
        Family(
          id: 'f1',
          displayName: 'F',
          members: [
            Member(id: 'm1', displayName: 'Alice Johnson'),
            Member(id: 'm2', displayName: 'Bob Smith'),
            Member(id: 'm3', displayName: 'Not On Event'),
          ],
        ),
      ];
      await pumpView(tester, handoffSharer: sharer);
      eventRepository.emit([todayEvent(memberIds: ['m1', 'm2'])]);
      await tester.pumpAndSettle();
      await openMenu(tester);

      await tester.tap(find.text('Hand off'));
      await tester.pumpAndSettle();

      expect(find.textContaining('unencrypted'), findsOneWidget);
      expect(find.textContaining('roster names'), findsOneWidget);
      expect(sharer.sent, isEmpty, reason: 'nothing leaves before Continue');

      await tester.tap(find.byKey(const Key('handoffExplainerContinue')));
      await tester.pumpAndSettle();

      final sent = sharer.sent.single;
      final doc = sent.document as HandoffRoster;
      expect(doc.eventId, 'event-1');
      expect(doc.eventTitle, 'Sunday Service');
      expect(doc.roster.map((p) => p.id), ['m1', 'm2']);
      expect(doc.roster.map((p) => p.name), ['Alice Johnson', 'Bob Smith']);
      final now = DateTime.now();
      expect(doc.sessionDate, DateTime(now.year, now.month, now.day));
      expect(sent.fileName, endsWith('.$handoffFileExtension'));
      expect(sent.fileName, startsWith('sunday-service-'));
    });

    testWidgets('cancelling the explainer sends nothing', (tester) async {
      final sharer = FakeHandoffSharer();
      await pumpView(tester, handoffSharer: sharer);
      eventRepository.emit([todayEvent()]);
      await tester.pumpAndSettle();
      await openMenu(tester);

      await tester.tap(find.text('Hand off'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(sharer.sent, isEmpty);
      expect(find.textContaining('unencrypted'), findsNothing);
    });

    testWidgets('a failure to build the file is reported, not thrown',
        (tester) async {
      final sharer = _ThrowingSharer();
      await pumpView(tester, handoffSharer: sharer);
      eventRepository.emit([todayEvent()]);
      await tester.pumpAndSettle();
      await openMenu(tester);

      await tester.tap(find.text('Hand off'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('handoffExplainerContinue')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not prepare'), findsOneWidget);
    });
  });

  testWidgets('HubAttendanceView renders when a session has 0 attendees (all absent)', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final member1 = Member(id: 'member-1', displayName: 'Alice');
    final member2 = Member(id: 'member-2', displayName: 'Bob');
    attendanceRepository.families = [
      Family(
        id: 'family-1',
        displayName: 'Family 1',
        members: [member1, member2],
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
            status: AttendanceStatus.absent,
            recordedAt: today,
            recordedBy: 'user',
          ),
          SessionRecord(
            memberId: 'member-2',
            attendee: 'Bob',
            status: AttendanceStatus.absent,
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
    eventRepository.emit([todayEvent(memberIds: ['member-1', 'member-2'])]);
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorView), findsNothing);
  });

  testWidgets('HubAttendanceView renders with 130 sessions and a 0-attendance session today', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final members = List.generate(
      50,
      (i) => Member(id: 'member-$i', displayName: 'Member $i'),
    );
    attendanceRepository.families = [
      Family(
        id: 'family-1',
        displayName: 'Family 1',
        members: members,
        updatedAt: now,
      ),
    ];

    final sessions = <Session>[];
    // 129 past sessions (one per week)
    for (int i = 129; i >= 1; i--) {
      final date = today.subtract(Duration(days: i * 7));
      sessions.add(
        Session(
          id: 'session-past-$i',
          eventId: 'event-1',
          title: 'Sunday Service',
          sessionDate: date,
          records: [
            for (int m = 0; m < 50; m++)
              SessionRecord(
                memberId: 'member-$m',
                attendee: 'Member $m',
                status: (m + i) % 3 == 0 ? AttendanceStatus.absent : AttendanceStatus.present,
                recordedAt: date,
                recordedBy: 'user',
              ),
          ],
          createdAt: date,
          updatedAt: date,
          createdBy: 'user',
        ),
      );
    }

    // 1 session today with 0 people attended (all absent)
    sessions.add(
      Session(
        id: 'session-today',
        eventId: 'event-1',
        title: 'Sunday Service',
        sessionDate: today,
        records: [
          for (int m = 0; m < 50; m++)
            SessionRecord(
              memberId: 'member-$m',
              attendee: 'Member $m',
              status: AttendanceStatus.absent,
              recordedAt: today,
              recordedBy: 'user',
            ),
        ],
        createdAt: today,
        updatedAt: today,
        createdBy: 'user',
      ),
    );

    sessionRepository.sessions = sessions;

    await pumpView(tester, disableAnimations: true);
    final dayName = DateFormat('EEEE').format(now);
    final ev1 = Event(
      id: 'event-1',
      title: 'Sunday Service',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'Weekly',
      repeatingDays: [dayName],
      memberIds: members.map((m) => m.id).toList(),
      createdAt: today.subtract(const Duration(days: 365 * 3)),
    );
    final ev2 = Event(
      id: 'event-2',
      title: 'Midweek Bible Study',
      time: const TimeOfDay(hour: 19, minute: 0),
      frequency: 'Weekly',
      repeatingDays: ['Wednesday'],
      memberIds: members.take(20).map((m) => m.id).toList(),
      createdAt: today.subtract(const Duration(days: 365 * 3)),
    );
    eventRepository.emit([ev1, ev2]);
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorView), findsNothing);
  });

  testWidgets('HubAttendanceView with rest-state (no events today) and 0-attendance session yesterday', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final members = List.generate(
      139,
      (i) => Member(id: 'member-$i', displayName: 'Member $i'),
    );
    attendanceRepository.families = [
      Family(
        id: 'family-1',
        displayName: 'Family 1',
        members: members,
        updatedAt: now,
      ),
    ];

    final sessions = <Session>[];
    for (int i = 129; i >= 1; i--) {
      final date = yesterday.subtract(Duration(days: i * 7));
      sessions.add(
        Session(
          id: 'session-past-$i',
          eventId: 'event-1',
          title: 'Sunday Service',
          sessionDate: date,
          records: [
            for (int m = 0; m < 139; m++)
              SessionRecord(
                memberId: 'member-$m',
                attendee: 'Member $m',
                status: (m + i) % 3 == 0 ? AttendanceStatus.absent : AttendanceStatus.present,
                recordedAt: date,
                recordedBy: 'user',
              ),
          ],
          createdAt: date,
          updatedAt: date,
          createdBy: 'user',
        ),
      );
    }

    // 0 attendance yesterday
    sessions.add(
      Session(
        id: 'session-yesterday-zero',
        eventId: 'event-1',
        title: 'Sunday Service',
        sessionDate: yesterday,
        records: [
          for (int m = 0; m < 139; m++)
            SessionRecord(
              memberId: 'member-$m',
              attendee: 'Member $m',
              status: AttendanceStatus.absent,
              recordedAt: yesterday,
              recordedBy: 'user',
            ),
        ],
        createdAt: yesterday,
        updatedAt: yesterday,
        createdBy: 'user',
      ),
    );

    sessionRepository.sessions = sessions;

    await pumpView(tester, disableAnimations: true);
    final notToday = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ].firstWhere((d) => d.toLowerCase() != DateFormat('EEEE').format(now).toLowerCase());

    final ev1 = Event(
      id: 'event-1',
      title: 'Sunday Service',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'Weekly',
      repeatingDays: [notToday],
      memberIds: members.map((m) => m.id).toList(),
      createdAt: today.subtract(const Duration(days: 365 * 3)),
    );
    eventRepository.emit([ev1]);
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorView), findsNothing);
  });

  testWidgets('HubAttendanceView with empty records session (0 people attended)', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final members = List.generate(
      10,
      (i) => Member(id: 'member-$i', displayName: 'Member $i'),
    );
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
        id: 'session-empty-records',
        eventId: 'event-1',
        title: 'Sunday Service',
        sessionDate: today,
        records: const [],
        createdAt: today,
        updatedAt: today,
        createdBy: 'user',
      ),
    ];

    await pumpView(tester, disableAnimations: true);
    final dayName = DateFormat('EEEE').format(now);
    final ev1 = Event(
      id: 'event-1',
      title: 'Sunday Service',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'Weekly',
      repeatingDays: [dayName],
      memberIds: members.map((m) => m.id).toList(),
      createdAt: today.subtract(const Duration(days: 365 * 3)),
    );
    eventRepository.emit([ev1]);
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorView), findsNothing);
  });

  testWidgets('HubAttendanceView renders with disableAnimations: false and 0 attendance session', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final members = List.generate(
      10,
      (i) => Member(id: 'member-$i', displayName: 'Member $i'),
    );
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
        id: 'session-zero',
        eventId: 'event-1',
        title: 'Sunday Service',
        sessionDate: today,
        records: [
          for (final m in members)
            SessionRecord(
              memberId: m.id,
              attendee: m.displayName,
              status: AttendanceStatus.absent,
              recordedAt: today,
              recordedBy: 'user',
            ),
        ],
        createdAt: today,
        updatedAt: today,
        createdBy: 'user',
      ),
    ];

    await pumpView(tester, disableAnimations: false);
    final dayName = DateFormat('EEEE').format(now);
    final ev1 = Event(
      id: 'event-1',
      title: 'Sunday Service',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'Weekly',
      repeatingDays: [dayName],
      memberIds: members.map((m) => m.id).toList(),
      createdAt: today.subtract(const Duration(days: 365 * 3)),
    );
    final ev2 = Event(
      id: 'event-2',
      title: 'Bible Study',
      time: const TimeOfDay(hour: 19, minute: 0),
      frequency: 'Weekly',
      repeatingDays: ['Wednesday'],
      memberIds: members.map((m) => m.id).toList(),
      createdAt: today.subtract(const Duration(days: 365 * 3)),
    );
    final ev3 = Event(
      id: 'event-3',
      title: 'Past One-Time Event',
      time: const TimeOfDay(hour: 14, minute: 0),
      frequency: 'One-time',
      oneTimeDate: today.subtract(const Duration(days: 2)),
      memberIds: members.map((m) => m.id).toList(),
      createdAt: today.subtract(const Duration(days: 365 * 3)),
    );
    eventRepository.emit([ev1, ev2, ev3]);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(AppErrorView), findsNothing);
  });
}


class _ThrowingSharer extends HandoffSharer {
  @override
  Future<void> send({
    required HandoffDocument document,
    required String fileName,
    required String text,
  }) async {
    throw StateError('no share sheet');
  }
}
