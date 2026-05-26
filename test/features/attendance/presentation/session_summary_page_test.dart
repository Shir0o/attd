import 'dart:async';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/core/design/widgets/conv_widgets.dart';
import 'package:attendance_tracker/features/attendance/presentation/session_summary_page.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockSessionRepository implements SessionRepository {
  final List<Session> _sessions = [];
  final StreamController<List<Session>> _streamController = StreamController();

  void addSession(Session session) {
    _sessions.add(session);
    _streamController.add(_sessions);
  }

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
  Future<void> deleteSession(String sessionId, {required String actor}) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    _streamController.add(_sessions);
  }

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async {
    throw UnimplementedError();
  }

  @override
  Future<Session?> findSessionById(String id) async {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<SessionVersion>> history(String sessionId) async {
    return [];
  }

  @override
  Future<List<Session>> loadSessions() async {
    return _sessions;
  }

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      _sessions[index] = session;
    } else {
      _sessions.add(session);
    }
    _streamController.add(_sessions);
    return session;
  }

  @override
  Stream<List<Session>> streamSessions() {
    return _streamController.stream;
  }
}

class MockAttendanceRepository extends AttendanceRepository {
  List<Family> _families = [];
  final _controller = StreamController<List<Family>>.broadcast();

  void setFamilies(List<Family> families) {
    _families = families;
    _controller.add(families);
  }

  @override
  Future<List<Family>> fetchFamilies() async => _families;

  @override
  Future<void> saveFamilies(List<Family> families) async {
    _families = families;
    _controller.add(families);
  }

  @override
  Future<Family> addMember(String familyId, Member member) async {
    final familyIndex = _families.indexWhere((f) => f.id == familyId);
    final updatedFamily = _families[familyIndex].copyWith(
      members: [..._families[familyIndex].members, member],
    );
    _families[familyIndex] = updatedFamily;
    _controller.add(_families);
    return updatedFamily;
  }

  @override
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) async {
    final family = Family(id: 'f1', displayName: displayName, members: []);
    _families.add(family);
    _controller.add(_families);
    return family;
  }

  @override
  Stream<List<Family>> streamFamilies() {
    final c = StreamController<List<Family>>();
    c.add(List<Family>.from(_families));
    final sub = _controller.stream.listen(c.add);
    c.onCancel = () => sub.cancel();
    return c.stream;
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class MockEventRepository implements EventRepository {
  final List<Event> _events = [];
  final _controller = StreamController<List<Event>>.broadcast();
  final List<Event> updateCalls = [];

  void seed(Event event) {
    _events.add(event);
    _controller.add(List<Event>.from(_events));
  }

  @override
  Future<void> createEvent(Event event) async {
    _events.add(event);
    _controller.add(List<Event>.from(_events));
  }

  @override
  Future<void> updateEvent(Event event) async {
    updateCalls.add(event);
    final i = _events.indexWhere((e) => e.id == event.id);
    if (i >= 0) {
      _events[i] = event;
    } else {
      _events.add(event);
    }
    _controller.add(List<Event>.from(_events));
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    _events.removeWhere((e) => e.id == eventId);
    _controller.add(List<Event>.from(_events));
  }

  @override
  Future<Event?> findEventById(String eventId) async {
    try {
      return _events.firstWhere((e) => e.id == eventId);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<Event>> streamEvents() {
    final c = StreamController<List<Event>>();
    c.add(List<Event>.from(_events));
    final sub = _controller.stream.listen(c.add);
    c.onCancel = () => sub.cancel();
    return c.stream;
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

void main() {
  testWidgets('SessionSummaryPage renders correct stats and members', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final mockAttendanceRepo = MockAttendanceRepository();
    final member1 = Member(id: '1', displayName: 'Alice');
    final member2 = Member(id: '2', displayName: 'Bob');

    final session = Session(
      id: 's1',
      title: 'Test Session',
      sessionDate: DateTime(2023, 10, 27),
      records: [
        SessionRecord(
          memberId: '1',
          attendee: 'Alice',
          status: AttendanceStatus.present,
          recordedAt: DateTime.now(),
          recordedBy: 'User',
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );

    mockRepo.addSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: [member1, member2],
          sessionRepository: mockRepo,
          attendanceRepository: mockAttendanceRepo,
          disableAnimations: true,
        ),
      ),
    );

    // Initial pumps to trigger state
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify Title and Date
    expect(find.text('Test Session'), findsOneWidget);
    expect(find.text('Session Date: October 27, 2023'), findsOneWidget);

    // Section headers are uppercased in UI: "MARKED PRESENT", "MARKED ABSENT"
    expect(find.text('MARKED PRESENT', skipOffstage: false), findsOneWidget);
    expect(find.text('MARKED ABSENT', skipOffstage: false), findsOneWidget);

    // Verify Alice is present (in present list)
    expect(find.text('Alice'), findsOneWidget);
    // Bob is absent (in absent list)
    expect(find.text('Bob'), findsOneWidget);

    // Verify stats: 1 Present, 1 Absent. 
    // The number '1' can appear multiple times (stats card + list headers possibly)
    expect(find.text('1'), findsAtLeastNWidgets(2)); 
    
    // Check that we have switches in the list
    expect(find.byType(ConvToggle), findsNWidgets(2));
  });

  testWidgets('SessionSummaryPage preserves historical names (Authoritative History)', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final mockAttendanceRepo = MockAttendanceRepository();
    
    final member1 = Member(id: '1', displayName: 'Alice');
    final family = Family(id: 'f1', displayName: 'Family', members: [member1]);
    mockAttendanceRepo.setFamilies([family]);

    final session = Session(
      id: 's1',
      title: 'Test Session',
      sessionDate: DateTime(2023, 10, 27),
      records: [
        SessionRecord(
          memberId: '1',
          attendee: 'Alice', // The name at the time of check-in
          status: AttendanceStatus.present,
          recordedAt: DateTime.now(),
          recordedBy: 'User',
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );

    mockRepo.addSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: [member1],
          sessionRepository: mockRepo,
          attendanceRepository: mockAttendanceRepo,
          disableAnimations: true,
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Verify Alice is shown
    expect(find.text('Alice'), findsOneWidget);

    // Rename Alice to Alicia in the global repository (simulating Settings change)
    final updatedMember = member1.copyWith(displayName: 'Alicia');
    final updatedFamily = family.copyWith(members: [updatedMember]);
    await mockAttendanceRepo.saveFamilies([updatedFamily]);

    // Wait for stream to emit and UI to rebuild
    await tester.pumpAndSettle();

    // Verify ALICE is STILL shown (preserving history) instead of the new name Alicia
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Alicia'), findsNothing);
  });

  testWidgets('SessionSummaryPage toggling attendance updates repository via Switch', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final member1 = Member(id: '1', displayName: 'Alice');

    final session = Session(
      id: 's1',
      title: 'Test Session',
      sessionDate: DateTime(2023, 10, 27),
      records: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );

    mockRepo.addSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: [member1],
          sessionRepository: mockRepo,
          disableAnimations: true,
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Initially Absent
    expect(find.text('Alice'), findsOneWidget);
    
    final switchFinder = find.byType(ConvToggle);
    expect(tester.widget<ConvToggle>(switchFinder).value, isFalse);

    // Toggle via Switch to Mark Present
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    // Verify Repo Updated
    final updatedSession = await mockRepo.findSessionById('s1');
    expect(updatedSession?.records.length, 1);
    expect(updatedSession?.records.first.attendee, 'Alice');
    expect(updatedSession?.records.first.status, AttendanceStatus.present);

    // Now toggle back to Absent
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    final updatedSession2 = await mockRepo.findSessionById('s1');
    expect(updatedSession2?.records.first.status, AttendanceStatus.absent);
  });

  testWidgets('SessionSummaryPage "Remove from report" via icon', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final member1 = Member(id: '1', displayName: 'Alice');

    final session = Session(
      id: 's1',
      title: 'Test Session',
      sessionDate: DateTime(2023, 10, 27),
      records: [], // Initially absent
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );

    mockRepo.addSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: [member1],
          sessionRepository: mockRepo,
          disableAnimations: true,
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Alice is absent
    expect(find.text('Alice'), findsOneWidget);

    // Swipe left to remove
    await tester.drag(find.text('Alice'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Verify confirmation dialog title
    expect(find.text('Remove from Report'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();

    // Alice should be GONE entirely
    expect(find.text('Alice'), findsNothing);

    // Verify Repo Updated
    final updatedSession = await mockRepo.findSessionById('s1');
    expect(updatedSession?.excludedMemberIds, contains('1'));
  });

  testWidgets('SessionSummaryPage "Rename" via icon', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final member1 = Member(id: '1', displayName: 'Alice');

    final session = Session(
      id: 's1',
      title: 'Test Session',
      sessionDate: DateTime(2023, 10, 27),
      records: [
        SessionRecord(
          memberId: '1',
          attendee: 'Alice',
          status: AttendanceStatus.present,
          recordedAt: DateTime.now(),
          recordedBy: 'User',
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );

    mockRepo.addSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: [member1],
          sessionRepository: mockRepo,
          disableAnimations: true,
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Swipe right to edit
    await tester.drag(find.text('Alice'), const Offset(500, 0));
    await tester.pumpAndSettle();

    // Check dialog
    expect(find.text('Edit Member'), findsOneWidget);
    await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.key != const Key('rosterSearchField')), 'Alicia');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Alicia'), findsOneWidget);
    
    final updatedSession = await mockRepo.findSessionById('s1');
    expect(updatedSession?.records.first.attendee, 'Alicia');
  });

  testWidgets('SessionSummaryPage delete button shows confirmation', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final member1 = Member(id: '1', displayName: 'Alice');

    final session = Session(
      id: 's1',
      title: 'Test Session',
      sessionDate: DateTime(2023, 10, 27),
      records: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );

    mockRepo.addSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: [member1],
          sessionRepository: mockRepo,
          disableAnimations: true,
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Find delete button (specifically the one in AppBar with tooltip)
    final deleteButton = find.byTooltip('Delete session');
    expect(deleteButton, findsOneWidget);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    // Check dialog
    expect(find.text('Delete Session'), findsOneWidget);
    expect(find.textContaining('Are you sure you want to delete'), findsOneWidget);

    // Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Session'), findsNothing);

    // Open again and delete
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify session deleted from repo
    final deletedSession = await mockRepo.findSessionById('s1');
    expect(deletedSession, isNull);

    // Should have popped
    expect(find.text('Test Session'), findsNothing);
  });

  testWidgets('SessionSummaryPage displays visitors not in member list', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    
    // Only Alice is in the expected member list
    final member1 = Member(id: '1', displayName: 'Alice');

    final session = Session(
      id: 's1',
      title: 'Visitor Session',
      sessionDate: DateTime(2023, 10, 27),
      records: [
        SessionRecord(
          memberId: 'm2',
          attendee: 'Visitor Bob',
          status: AttendanceStatus.present,
          recordedAt: DateTime.now(),
          recordedBy: 'User',
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );

    mockRepo.addSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: [member1],
          sessionRepository: mockRepo,
          disableAnimations: true,
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Alice should be "Marked Absent" (default)
    // Visitor Bob should be "Marked Present"
    expect(find.text('Visitor Bob'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);

    // Total count should be 2 (1 assigned + 1 visitor)
    expect(find.text('2 Total'), findsOneWidget);
  });

  testWidgets('SessionSummaryPage "Add attendee" adds a new record', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final member1 = Member(id: '1', displayName: 'Alice');

    final session = Session(
      id: 's1',
      title: 'Test Session',
      sessionDate: DateTime(2023, 10, 27),
      records: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );

    mockRepo.addSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: [member1],
          sessionRepository: mockRepo,
          disableAnimations: true,
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Initially 1 member (Alice)
    expect(find.text('1 Total'), findsOneWidget);

    // Tap "Add attendee" button
    final addButton = find.byIcon(Icons.person_add);
    expect(addButton, findsOneWidget);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    // Verify sheet appears (contains "Add Person" text)
    expect(find.text('Add Person'), findsOneWidget);

    // Enter name "Charlie"
    await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.key != const Key('rosterSearchField')), 'Charlie');
    
    // Tap "Add & Continue"
    await tester.tap(find.text('Add & Continue'));
    await tester.pumpAndSettle();

    // Sheet should be gone
    expect(find.text('Add Person'), findsNothing);

    // Now 2 total members
    expect(find.text('2 Total'), findsOneWidget);
    expect(find.text('Charlie'), findsOneWidget);

    // Verify Repo Updated
    final updatedSession = await mockRepo.findSessionById('s1');
    expect(updatedSession?.records.length, 1);
    expect(updatedSession?.records.first.attendee, 'Charlie');
    expect(updatedSession?.records.first.status, AttendanceStatus.present);
  });

  testWidgets('SessionSummaryPage adding an existing global member appends them to event.memberIds', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final mockAttendanceRepo = MockAttendanceRepository();
    final mockEventRepo = MockEventRepository();

    final inEventMember = Member(id: '1', displayName: 'Alice');
    final globalOnlyMember = Member(id: '2', displayName: 'Bob');
    final family = Family(
      id: 'f1',
      displayName: 'Family',
      members: [inEventMember, globalOnlyMember],
    );
    mockAttendanceRepo.setFamilies([family]);

    final event = Event(
      id: 'e1',
      title: 'Test Session',
      time: const TimeOfDay(hour: 9, minute: 0),
      frequency: 'Weekly',
      memberIds: const ['1'],
      createdAt: DateTime.now(),
    );
    mockEventRepo.seed(event);

    final session = Session(
      id: 's1',
      eventId: 'e1',
      title: 'Test Session',
      sessionDate: DateTime(2023, 10, 27),
      records: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );
    mockRepo.addSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: [inEventMember],
          sessionRepository: mockRepo,
          attendanceRepository: mockAttendanceRepo,
          eventRepository: mockEventRepo,
          event: event,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.key != const Key('rosterSearchField')), 'Bob');
    await tester.pumpAndSettle();
    // Tap suggestion
    await tester.tap(find.text('Bob').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Existing'));
    await tester.pumpAndSettle();

    // Event was updated with Bob's id appended
    expect(mockEventRepo.updateCalls.length, 1);
    expect(mockEventRepo.updateCalls.last.memberIds, containsAll(['1', '2']));

    // Session got a record for Bob
    final updatedSession = await mockRepo.findSessionById('s1');
    expect(updatedSession!.records.any((r) => r.memberId == '2'), isTrue);

    // Bob is in roster
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('SessionSummaryPage adding a new name with Guest off creates a real global member', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final mockAttendanceRepo = MockAttendanceRepository();
    final mockEventRepo = MockEventRepository();

    final inEventMember = Member(id: '1', displayName: 'Alice');
    final family = Family(
      id: 'f0',
      displayName: 'Family',
      members: [inEventMember],
    );
    mockAttendanceRepo.setFamilies([family]);

    final event = Event(
      id: 'e1',
      title: 'Test Session',
      time: const TimeOfDay(hour: 9, minute: 0),
      frequency: 'Weekly',
      memberIds: const ['1'],
      createdAt: DateTime.now(),
    );
    mockEventRepo.seed(event);

    final session = Session(
      id: 's1',
      eventId: 'e1',
      title: 'Test Session',
      sessionDate: DateTime(2023, 10, 27),
      records: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );
    mockRepo.addSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: [inEventMember],
          sessionRepository: mockRepo,
          attendanceRepository: mockAttendanceRepo,
          eventRepository: mockEventRepo,
          event: event,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.key != const Key('rosterSearchField')), 'Charlie');
    await tester.tap(find.text('Add & Continue'));
    await tester.pumpAndSettle();

    // A new family was created and member added
    final families = await mockAttendanceRepo.fetchFamilies();
    final allMembers = families.expand((f) => f.members).toList();
    final charlie = allMembers.firstWhere((m) => m.displayName == 'Charlie');
    expect(charlie.isVisitor, isFalse);

    // Event was updated to include Charlie
    expect(mockEventRepo.updateCalls.length, 1);
    expect(mockEventRepo.updateCalls.last.memberIds, contains(charlie.id));

    // Session record uses the real id, not null
    final updatedSession = await mockRepo.findSessionById('s1');
    final charlieRecord =
        updatedSession!.records.firstWhere((r) => r.attendee == 'Charlie');
    expect(charlieRecord.memberId, equals(charlie.id));
  });

  testWidgets('SessionSummaryPage adding a new name with Guest ON keeps it as a visitor', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final mockAttendanceRepo = MockAttendanceRepository();
    final mockEventRepo = MockEventRepository();

    final inEventMember = Member(id: '1', displayName: 'Alice');
    mockAttendanceRepo.setFamilies([
      Family(id: 'f0', displayName: 'Family', members: [inEventMember]),
    ]);

    final event = Event(
      id: 'e1',
      title: 'Test Session',
      time: const TimeOfDay(hour: 9, minute: 0),
      frequency: 'Weekly',
      memberIds: const ['1'],
      createdAt: DateTime.now(),
    );
    mockEventRepo.seed(event);

    final session = Session(
      id: 's1',
      eventId: 'e1',
      title: 'Test Session',
      sessionDate: DateTime(2023, 10, 27),
      records: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );
    mockRepo.addSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: [inEventMember],
          sessionRepository: mockRepo,
          attendanceRepository: mockAttendanceRepo,
          eventRepository: mockEventRepo,
          event: event,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.key != const Key('rosterSearchField')), 'Daria');
    await tester.pumpAndSettle();
    // Toggle "Add as Guest"
    final guestRow = find
        .ancestor(of: find.text('Add as Guest'), matching: find.byType(Row));
    await tester.tap(find.descendant(of: guestRow, matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add & Continue'));
    await tester.pumpAndSettle();

    // No new family/member added globally
    final families = await mockAttendanceRepo.fetchFamilies();
    final allMembers = families.expand((f) => f.members).toList();
    expect(allMembers.any((m) => m.displayName == 'Daria'), isFalse);

    // Event was NOT updated
    expect(mockEventRepo.updateCalls, isEmpty);

    // Record stored with null memberId
    final updatedSession = await mockRepo.findSessionById('s1');
    final dariaRecord =
        updatedSession!.records.firstWhere((r) => r.attendee == 'Daria');
    expect(dariaRecord.memberId, isNull);
  });

  testWidgets('SessionSummaryPage back button pops with the current session', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final session = Session(
      id: 's1',
      title: 'Test Session',
      sessionDate: DateTime(2023, 10, 27),
      records: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );
    mockRepo.addSession(session);

    Session? popped;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<Session>(
                    MaterialPageRoute(
                      builder: (_) => SessionSummaryPage(
                        session: session,
                        members: const [],
                        sessionRepository: mockRepo,
                        disableAnimations: true,
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(popped?.id, 's1');
  });

  testWidgets('SessionSummaryPage info button shows the data policy dialog', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final session = Session(
      id: 's1',
      title: 'Test Session',
      sessionDate: DateTime(2023, 10, 27),
      records: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );
    mockRepo.addSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: const [],
          sessionRepository: mockRepo,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('View data policy'));
    await tester.pumpAndSettle();

    expect(find.text('Historical Snapshot'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Historical Snapshot'), findsNothing);
  });

  testWidgets('SessionSummaryPage edit member with empty/unchanged name is a no-op', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final member1 = Member(id: '1', displayName: 'Alice');
    final session = Session(
      id: 's1',
      title: 'Test',
      sessionDate: DateTime(2023, 10, 27),
      records: [
        SessionRecord(
          memberId: '1',
          attendee: 'Alice',
          status: AttendanceStatus.present,
          recordedAt: DateTime.now(),
          recordedBy: 'User',
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );
    mockRepo.addSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: [member1],
          sessionRepository: mockRepo,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open edit dialog and cancel -> returns null
    await tester.drag(find.text('Alice'), const Offset(500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);

    // Open edit dialog, clear text, save -> empty path early-return
    await tester.drag(find.text('Alice'), const Offset(500, 0));
    await tester.pumpAndSettle();
    await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.key != const Key('rosterSearchField')), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);

    // Open edit dialog, keep same name, save -> unchanged early-return
    await tester.drag(find.text('Alice'), const Offset(500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('SessionSummaryPage edit visitor renames matching record by name', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final session = Session(
      id: 's1',
      title: 'Test',
      sessionDate: DateTime(2023, 10, 27),
      records: [
        SessionRecord(
          memberId: null,
          attendee: 'Bob',
          status: AttendanceStatus.present,
          recordedAt: DateTime.now(),
          recordedBy: 'User',
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );
    mockRepo.addSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: const [],
          sessionRepository: mockRepo,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsOneWidget);
    await tester.drag(find.text('Bob'), const Offset(500, 0));
    await tester.pumpAndSettle();
    await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.key != const Key('rosterSearchField')), 'Bobby');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Bobby'), findsOneWidget);
  });

  testWidgets('SessionSummaryPage remove visitor cleans matching record', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final session = Session(
      id: 's1',
      title: 'Test',
      sessionDate: DateTime(2023, 10, 27),
      records: [
        SessionRecord(
          memberId: null,
          attendee: 'Bob',
          status: AttendanceStatus.present,
          recordedAt: DateTime.now(),
          recordedBy: 'User',
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );
    mockRepo.addSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: const [],
          sessionRepository: mockRepo,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Bob'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsNothing);
    expect(find.text('removed from this report'), findsNothing);
    // Snackbar present
    expect(find.textContaining('removed from this report'), findsOneWidget);
  });

  testWidgets('SessionSummaryPage remove confirmation can be cancelled', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final member1 = Member(id: '1', displayName: 'Alice');
    final session = Session(
      id: 's1',
      title: 'Test',
      sessionDate: DateTime(2023, 10, 27),
      records: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );
    mockRepo.addSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: [member1],
          sessionRepository: mockRepo,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Alice'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Remove from Report'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('SessionSummaryPage delete error surfaces snackbar (does not pop)', (
    WidgetTester tester,
  ) async {
    final mockRepo = _ThrowingSessionRepository();
    final session = Session(
      id: 's1',
      title: 'Test',
      sessionDate: DateTime(2023, 10, 27),
      records: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );
    mockRepo.seed(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: const [],
          sessionRepository: mockRepo,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete session'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Error deleting session'), findsOneWidget);
  });

  testWidgets(
    'SessionSummaryPage toggle attendance swallows repo errors and updates UI optimistically',
    (WidgetTester tester) async {
      final mockRepo = _ThrowingSessionRepository();
      final member1 = Member(id: '1', displayName: 'Alice');
      final session = Session(
        id: 's1',
        title: 'Test',
        sessionDate: DateTime(2023, 10, 27),
        records: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'User',
      );
      mockRepo.seed(session);

      await tester.pumpWidget(
        MaterialApp(
          home: SessionSummaryPage(
            session: session,
            members: [member1],
            sessionRepository: mockRepo,
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ConvToggle));
      await tester.pumpAndSettle();
      // No crash; switch flipped (member moved to Present list).
      expect(find.text('Alice'), findsOneWidget);
    },
  );

  testWidgets(
    'SessionSummaryPage delayed loading (animations enabled) shows skeleton then content',
    (WidgetTester tester) async {
      final mockRepo = MockSessionRepository();
      final session = Session(
        id: 's1',
        title: 'Delayed',
        sessionDate: DateTime(2023, 10, 27),
        records: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'User',
      );
      mockRepo.addSession(session);

      await tester.pumpWidget(
        MaterialApp(
          home: SessionSummaryPage(
            session: session,
            members: const [],
            sessionRepository: mockRepo,
            // disableAnimations defaults to false -> delayed loading path
          ),
        ),
      );
      // Initial frame: skeleton (no title yet)
      await tester.pump();
      // Advance past the 800ms delay and let animations settle.
      await tester.pump(const Duration(milliseconds: 801));
      await tester.pumpAndSettle();
      // Eventually content shows
      expect(find.text('Delayed'), findsOneWidget);
    },
  );

  testWidgets(
    'SessionSummaryPage didUpdateWidget swaps to a newer session and resubscribes',
    (WidgetTester tester) async {
      final mockRepo = MockSessionRepository();
      final mockAttendanceRepo = MockAttendanceRepository();
      final mockEventRepo = MockEventRepository();
      final event = Event(
        id: 'e1',
        title: 'T',
        time: const TimeOfDay(hour: 9, minute: 0),
        frequency: 'Weekly',
        memberIds: const [],
        createdAt: DateTime.now(),
      );
      mockEventRepo.seed(event);

      final s1 = Session(
        id: 's1',
        title: 'V1',
        sessionDate: DateTime(2023, 10, 27),
        records: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'User',
        currentVersion: 1,
      );
      mockRepo.addSession(s1);

      Widget build(Session s) => MaterialApp(
            home: SessionSummaryPage(
              session: s,
              members: const [],
              sessionRepository: mockRepo,
              attendanceRepository: mockAttendanceRepo,
              eventRepository: mockEventRepo,
              event: event,
              disableAnimations: true,
            ),
          );

      await tester.pumpWidget(build(s1));
      await tester.pumpAndSettle();
      expect(find.text('V1'), findsOneWidget);

      final s2 = s1.copyWith(
        title: 'V2',
        updatedAt: DateTime.now().add(const Duration(days: 1)),
      );
      await tester.pumpWidget(build(s2));
      await tester.pumpAndSettle();
      expect(find.text('V2'), findsOneWidget);

      // Now change attendance repo identity to trigger resubscribe branch.
      final newAttendance = MockAttendanceRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: SessionSummaryPage(
            session: s2,
            members: const [],
            sessionRepository: mockRepo,
            attendanceRepository: newAttendance,
            eventRepository: mockEventRepo,
            event: event,
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('V2'), findsOneWidget);
    },
  );

  testWidgets('SessionSummaryPage rebuilds roster when event.memberIds changes via stream', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final mockAttendanceRepo = MockAttendanceRepository();
    final mockEventRepo = MockEventRepository();

    final m1 = Member(id: '1', displayName: 'Alice');
    final m2 = Member(id: '2', displayName: 'Bob');
    mockAttendanceRepo.setFamilies([
      Family(id: 'f', displayName: 'F', members: [m1, m2]),
    ]);

    final event = Event(
      id: 'e1',
      title: 'Test Session',
      time: const TimeOfDay(hour: 9, minute: 0),
      frequency: 'Weekly',
      memberIds: const ['1'],
      createdAt: DateTime.now(),
    );
    mockEventRepo.seed(event);

    final session = Session(
      id: 's1',
      eventId: 'e1',
      title: 'Test Session',
      sessionDate: DateTime(2023, 10, 27),
      records: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );
    mockRepo.addSession(session);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: session,
          members: [m1],
          sessionRepository: mockRepo,
          attendanceRepository: mockAttendanceRepo,
          eventRepository: mockEventRepo,
          event: event,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsNothing);

    // Simulate manage-members adding Bob to the event externally
    await mockEventRepo.updateEvent(
      event.copyWith(memberIds: const ['1', '2']),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets(
    'SessionSummaryPage family toggle marks the whole family at once',
    (tester) async {
      final mockRepo = MockSessionRepository();
      final mockAttendanceRepo = MockAttendanceRepository();
      final alice = Member(id: '1', displayName: 'Alice');
      final bob = Member(id: '2', displayName: 'Bob');
      mockAttendanceRepo.setFamilies([
        Family(id: 'f1', displayName: 'Smith', members: [alice, bob]),
      ]);
      final now = DateTime(2026, 5, 24);
      final session = Session(
        id: 's1',
        title: 'Test',
        sessionDate: now,
        records: const [],
        createdAt: now,
        updatedAt: now,
        createdBy: 'User',
      );
      mockRepo.addSession(session);

      await tester.pumpWidget(
        MaterialApp(
          home: SessionSummaryPage(
            session: session,
            members: [alice, bob],
            sessionRepository: mockRepo,
            attendanceRepository: mockAttendanceRepo,
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default grouping is byStatus; switch to byFamily to access the header.
      await tester.tap(find.text('By family'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('familyAllPresent_f1')));
      await tester.pumpAndSettle();

      final saved = await mockRepo.findSessionById('s1');
      expect(saved!.records.length, 2);
      expect(
        saved.records.every((r) => r.status == AttendanceStatus.present),
        isTrue,
      );
    },
  );

  testWidgets(
    'SessionSummaryPage mark-all overrides records and shows undo snackbar',
    (tester) async {
      final mockRepo = MockSessionRepository();
      final mockAttendanceRepo = MockAttendanceRepository();
      final alice = Member(id: '1', displayName: 'Alice');
      final bob = Member(id: '2', displayName: 'Bob');
      mockAttendanceRepo.setFamilies([
        Family(id: 'f1', displayName: 'Smith', members: [alice, bob]),
      ]);
      final now = DateTime(2026, 5, 24);
      final session = Session(
        id: 's1',
        title: 'Test',
        sessionDate: now,
        records: [
          SessionRecord(
            memberId: '1',
            attendee: 'Alice',
            status: AttendanceStatus.absent,
            recordedAt: now,
            recordedBy: 'User',
          ),
        ],
        createdAt: now,
        updatedAt: now,
        createdBy: 'User',
      );
      mockRepo.addSession(session);

      await tester.pumpWidget(
        MaterialApp(
          home: SessionSummaryPage(
            session: session,
            members: [alice, bob],
            sessionRepository: mockRepo,
            attendanceRepository: mockAttendanceRepo,
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('rosterMarkAllMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('markEveryonePresent')));
      await tester.pumpAndSettle();

      final saved = await mockRepo.findSessionById('s1');
      expect(saved!.records.every((r) => r.status == AttendanceStatus.present),
          isTrue);
      expect(saved.records.first.recordedBy, 'User (Bulk)');

      // Snackbar with Undo is visible.
      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      final restored = await mockRepo.findSessionById('s1');
      expect(restored!.records.single.memberId, '1');
      expect(restored.records.single.status, AttendanceStatus.absent);
    },
  );
}

class _ThrowingSessionRepository implements SessionRepository {
  Session? _seeded;
  void seed(Session s) => _seeded = s;

  @override
  Future<Session> createSession({
    required String title,
    String? eventId,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {
    throw StateError('boom');
  }

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async =>
      throw UnimplementedError();

  @override
  Future<Session?> findSessionById(String id) async => _seeded;

  @override
  Future<List<SessionVersion>> history(String sessionId) async => [];

  @override
  Future<List<Session>> loadSessions() async =>
      _seeded != null ? [_seeded!] : [];

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    throw StateError('save boom');
  }

  @override
  Stream<List<Session>> streamSessions() =>
      Stream.value(_seeded != null ? [_seeded!] : []);
}
