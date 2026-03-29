import 'dart:async';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/presentation/session_summary_page.dart';
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

class MockAttendanceRepository implements AttendanceRepository {
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
  Future<Family> addFamily(String displayName) async {
    final family = Family(id: 'f1', displayName: displayName, members: []);
    _families.add(family);
    _controller.add(_families);
    return family;
  }

  @override
  Stream<List<Family>> streamFamilies() {
    return _controller.stream;
  }

  @override
  Future<void> refresh() async {}
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
        ),
      ),
    );

    // Wait for the initial loading animation and delay
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Verify Title and Date
    expect(find.text('Test Session'), findsOneWidget);
    expect(find.text('Session Date: October 27, 2023'), findsOneWidget);

    // Verify Stats (Alice Present, Bob Absent (default))

    // Alice should be in "Marked Present" section
    final presentHeader = find.text('Marked Present');
    expect(presentHeader, findsOneWidget);

    final absentHeader = find.text('Marked Absent');
    expect(absentHeader, findsOneWidget);

    // Alice is present
    expect(find.widgetWithText(SliverList, 'Alice'), findsOneWidget);
    // Bob is absent
    expect(find.widgetWithText(SliverList, 'Bob'), findsOneWidget);

    // Verify switches
    final aliceSwitch = find.descendant(
       of: find.widgetWithText(SliverList, 'Alice'),
       matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(aliceSwitch).value, isTrue);

    final bobSwitch = find.descendant(
       of: find.widgetWithText(SliverList, 'Bob'),
       matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(bobSwitch).value, isFalse);

    // Accessibility
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
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
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));
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

  testWidgets('SessionSummaryPage toggling switch updates repository', (
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
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Initially Absent
    final switchFinder = find.byType(Switch);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);

    // Toggle to Present
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    // Verify Repo Updated
    final updatedSession = await mockRepo.findSessionById('s1');
    expect(updatedSession?.records.length, 1);
    expect(updatedSession?.records.first.attendee, 'Alice');
    expect(updatedSession?.records.first.status, AttendanceStatus.present);
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
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));
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
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Alice should be "Marked Absent" (default)
    // Visitor Bob should be "Marked Present"
    expect(find.widgetWithText(SliverList, 'Visitor Bob'), findsOneWidget);
    expect(find.widgetWithText(SliverList, 'Alice'), findsOneWidget);

    // Verify Bob is in "Marked Present"
    final presentSection = find.widgetWithText(SliverList, 'Visitor Bob');
    final bobSwitch = find.descendant(
      of: presentSection,
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(bobSwitch).value, isTrue);
    
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
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));
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
    await tester.enterText(find.byType(TextField), 'Charlie');
    
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

  testWidgets('SessionSummaryPage "Remove from report" removes person locally', (
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
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Alice is present
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('1 Total'), findsOneWidget);

    // Tap Remove icon for Alice
    final removeButton = find.byTooltip('Remove from report');
    expect(removeButton, findsOneWidget);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    // Verify confirmation dialog
    expect(find.text('Remove from Report'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    // Alice should be GONE entirely (not even in Absent list because she is excluded)
    expect(find.text('Alice'), findsNothing);
    expect(find.text('0 Total'), findsOneWidget);

    // Verify Repo Updated: records empty, ID in excluded
    final updatedSession = await mockRepo.findSessionById('s1');
    expect(updatedSession?.records, isEmpty);
    expect(updatedSession?.excludedMemberIds, contains('1'));
  });
}
