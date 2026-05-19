import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/sessions/presentation/event_history_page.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';

import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';

class MockAttendanceRepository implements AttendanceRepository {
  @override
  Future<List<Family>> fetchFamilies() async => [];
  @override
  Future<void> saveFamilies(List<Family> families) async {}
  @override
  Future<Family> addMember(String familyId, Member member) async =>
      throw UnimplementedError();
  @override
  Future<Family> addFamily(String displayName) async =>
      throw UnimplementedError();
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
  @override
  Future<void> createEvent(Event event) async {}
  @override
  Future<void> updateEvent(Event event) async {}
  @override
  Future<void> deleteEvent(String eventId) async {}
  @override
  Future<Event?> findEventById(String eventId) async => null;
  @override
  Stream<List<Event>> streamEvents() => Stream.value([]);
  @override
  Future<void> refresh() async {}
  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class MockSessionRepository implements SessionRepository {
  final _controller = StreamController<List<Session>>();

  List<String> deletedIds = [];
  Object? deleteError;
  List<({String title, DateTime date, String? eventId})> createdSessions = [];
  Session? findSessionByIdResult;
  int refreshCalls = 0;

  void emit(List<Session> sessions) {
    _controller.add(sessions);
  }

  @override
  Stream<List<Session>> streamSessions() {
    return _controller.stream;
  }

  @override
  Future<List<Session>> loadSessions() async => [];

  @override
  Future<Session?> findSessionById(String id) async => findSessionByIdResult;

  @override
  Future<Session> createSession({
    required String title,
    String? eventId,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async {
    createdSessions
        .add((title: title, date: sessionDate, eventId: eventId));
    return Session(
      id: 'created-${createdSessions.length}',
      eventId: eventId,
      title: title,
      sessionDate: sessionDate,
      records: records,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: actor,
    );
  }

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    throw UnimplementedError();
  }

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {
    if (deleteError != null) throw deleteError!;
    deletedIds.add(sessionId);
  }

  @override
  Future<List<SessionVersion>> history(String sessionId) async {
    return [];
  }

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}

  @override
  Future<void> refresh() async {
    refreshCalls++;
  }

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

void main() {
  testWidgets('EventHistoryPage displays sessions for the event', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final mockAttendanceRepo = MockAttendanceRepository();
    final event = Event(
      id: '1',
      title: 'Morning Standup',
      time: const TimeOfDay(hour: 9, minute: 0),
      frequency: 'Daily',
      repeatingDays: ['Monday'],
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventHistoryPage(
          event: event,
          sessionRepository: mockRepo,
          attendanceRepository: mockAttendanceRepo,
          eventRepository: MockEventRepository(),
          disableAnimations: true,
        ),
      ),
    );

    final session = Session(
      id: 's1',
      title: 'Morning Standup',
      sessionDate: DateTime(2023, 10, 7),
      records: [
        SessionRecord(
          memberId: 'm1',
          attendee: 'A',
          status: AttendanceStatus.present,
          recordedAt: DateTime.now(),
          recordedBy: 'User',
        ),
        SessionRecord(
          memberId: 'm2',
          attendee: 'B',
          status: AttendanceStatus.absent,
          recordedAt: DateTime.now(),
          recordedBy: 'User',
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
      currentVersion: 1,
    );

    mockRepo.emit([session]);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Morning Standup History'), findsOneWidget);
    expect(find.text('Oct 7, 2023'), findsOneWidget);
    expect(find.text('1 Present'), findsOneWidget);
    expect(find.text('1 Absent'), findsOneWidget);
  });

  testWidgets('EventHistoryPage filters members based on event.memberIds', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    
    // Event only includes member '1'
    final event = Event(
      id: 'e1',
      title: 'Restricted Event',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'One-time',
      memberIds: ['1'],
      createdAt: DateTime.now(),
    );

    // Mock attendance repo returns 2 members
    final member1 = Member(id: '1', displayName: 'Member One');
    final member2 = Member(id: '2', displayName: 'Member Two');
    
    // Custom mock repo to return members
    final customAttendanceRepo = _MockAttendanceRepoWithMembers([member1, member2]);

    await tester.pumpWidget(
      MaterialApp(
        home: EventHistoryPage(
          event: event,
          sessionRepository: mockRepo,
          attendanceRepository: customAttendanceRepo,
          eventRepository: MockEventRepository(),
          disableAnimations: true,
        ),
      ),
    );

    final session = Session(
      id: 's1',
      title: 'Restricted Event',
      sessionDate: DateTime(2023, 10, 7),
      records: [
        SessionRecord(
          memberId: '1',
          attendee: 'Member One',
          status: AttendanceStatus.present,
          recordedAt: DateTime.now(),
          recordedBy: 'User',
        ),
        // Record for member 2 who is NOT assigned to this event
        SessionRecord(
          memberId: '2',
          attendee: 'Member Two',
          status: AttendanceStatus.present,
          recordedAt: DateTime.now(),
          recordedBy: 'User',
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
      currentVersion: 1,
    );

    mockRepo.emit([session]);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    // Member One is assigned and present -> 1 Present
    // Member Two is NOT assigned, but has a present record -> Should also count as 1 Present (visitor)
    // So total Present should be 2
    expect(find.text('2 Present'), findsOneWidget);
    
    // Only Member One is assigned. He is present. 
    // So 0 assigned members are absent.
    // Member Two is not assigned, so he shouldn't be counted as 'Absent' by default.
    expect(find.text('0 Absent'), findsOneWidget);
  });

  testWidgets('EventHistoryPage displays a FAB to make up previous sessions', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final mockAttendanceRepo = MockAttendanceRepository();

    final event = Event(
      id: 'e1',
      title: 'History Event',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'Weekly',
      repeatingDays: ['Monday'],
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventHistoryPage(
          event: event,
          sessionRepository: mockRepo,
          attendanceRepository: mockAttendanceRepo,
          eventRepository: MockEventRepository(),
          disableAnimations: true,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // Wait for _init delay
    await tester.pumpAndSettle();

    // Should have a FAB with Hero tag 'fab'
    final fabFinder = find.byType(FloatingActionButton);
    expect(fabFinder, findsOneWidget);
    
    final fab = tester.widget<FloatingActionButton>(fabFinder);
    expect(fab.heroTag, 'fab');
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  _registerUncoveredPathTests();
}

class _MockAttendanceRepoWithMembers extends MockAttendanceRepository {
  final List<Member> members;
  _MockAttendanceRepoWithMembers(this.members);

  @override
  Future<List<Family>> fetchFamilies() async {
    return [Family(id: 'f1', displayName: 'Family', members: members)];
  }
}

void _registerUncoveredPathTests() {
  group('EventHistoryPage uncovered paths', () {
    late MockSessionRepository sessions;
    late MockAttendanceRepository attendance;
    late Event event;

    setUp(() {
      sessions = MockSessionRepository();
      attendance = MockAttendanceRepository();
      event = Event(
        id: 'e1',
        title: 'History Event',
        time: const TimeOfDay(hour: 10, minute: 0),
        frequency: 'Weekly',
        repeatingDays: ['Monday'],
        createdAt: DateTime.now(),
      );
    });

    Widget host() => MaterialApp(
          home: EventHistoryPage(
            event: event,
            sessionRepository: sessions,
            attendanceRepository: attendance,
            eventRepository: MockEventRepository(),
            disableAnimations: true,
          ),
        );

    Session sampleSession({
      String id = 's1',
      String title = 'History Event',
      String? eventId = 'e1',
    }) {
      return Session(
        id: id,
        eventId: eventId,
        title: title,
        sessionDate: DateTime(2024, 1, 1),
        records: const [],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        createdBy: 'tester',
      );
    }

    testWidgets('renders the empty state when there are no event sessions',
        (tester) async {
      await tester.pumpWidget(host());
      sessions.emit([]);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(find.text('No history found'), findsOneWidget);
      expect(find.byIcon(Icons.history_outlined), findsOneWidget);
    });

    testWidgets('legacy sessions without eventId match by title', (tester) async {
      await tester.pumpWidget(host());
      sessions.emit([sampleSession(eventId: null)]);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(find.text('Jan 1, 2024'), findsOneWidget);
    });

    testWidgets('pull-to-refresh triggers repository refresh', (tester) async {
      await tester.pumpWidget(host());
      sessions.emit([sampleSession()]);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(sessions.refreshCalls, greaterThanOrEqualTo(1));
    });

    testWidgets('swipe-to-delete cancel keeps the session', (tester) async {
      await tester.pumpWidget(host());
      sessions.emit([sampleSession()]);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Jan 1, 2024'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Delete Session'), findsAtLeastNWidgets(1));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(sessions.deletedIds, isEmpty);
    });

    testWidgets('swipe-to-delete confirm deletes the session', (tester) async {
      await tester.pumpWidget(host());
      sessions.emit([sampleSession()]);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Jan 1, 2024'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(sessions.deletedIds, ['s1']);
      expect(find.text('Session deleted'), findsOneWidget);
    });

    testWidgets('swipe-to-delete surfaces errors via snackbar', (tester) async {
      sessions.deleteError = Exception('disk full');
      await tester.pumpWidget(host());
      sessions.emit([sampleSession()]);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Jan 1, 2024'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error deleting session'), findsOneWidget);
    });

    testWidgets('FAB opens the date picker', (tester) async {
      await tester.pumpWidget(host());
      sessions.emit([]);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // showDatePicker renders OK and Cancel actions.
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Dismiss to avoid leaving the picker open.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(sessions.createdSessions, isEmpty);
    });

    testWidgets('back button pops the page', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EventHistoryPage(
                      event: event,
                      sessionRepository: sessions,
                      attendanceRepository: attendance,
                      eventRepository: MockEventRepository(),
                      disableAnimations: true,
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      sessions.emit([]);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(find.text('History Event History'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('tapping a session navigates to SessionSummaryPage', (tester) async {
      await tester.pumpWidget(host());
      sessions.emit([sampleSession()]);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Jan 1, 2024'));
      await tester.pumpAndSettle();

      // SessionSummaryPage shows the session date label.
      expect(find.text('Session Date: January 1, 2024'), findsOneWidget);
    });

    testWidgets('FAB date picker confirm creates a make-up session and cleans up if empty',
        (tester) async {
      await tester.pumpWidget(host());
      sessions.emit([]);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Date picker initial date is today; just confirm by tapping OK.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // A new session was created for the make-up.
      expect(sessions.createdSessions.length, 1);
      expect(sessions.createdSessions.first.eventId, 'e1');

      // AttendanceDeckPage gets pushed; pop it back without recording anything
      // so the cleanup path deletes the empty session.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      // findSessionById returns null by default -> finalSession from result
      // is null path; deletion only happens when finalSession non-null & empty.
      // To exercise deletion, set findSessionByIdResult to a non-null empty session.
      sessions.findSessionByIdResult = Session(
        id: 'created-2',
        eventId: 'e1',
        title: 'History Event',
        sessionDate: DateTime(2024, 1, 1),
        records: const [],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        createdBy: 'tester',
      );

      // Re-run the picker flow to trigger cleanup.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final navigator2 = tester.state<NavigatorState>(find.byType(Navigator));
      navigator2.pop();
      await tester.pumpAndSettle();

      expect(sessions.deletedIds, contains('created-2'));
    });
  });
}
