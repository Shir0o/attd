import 'dart:async';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/presentation/attendance_deck_page.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';

class MockAttendanceRepository implements AttendanceRepository {
  @override
  Future<List<Family>> fetchFamilies() async => [];
  @override
  Future<void> saveFamilies(List<Family> families) async {}
  @override
  Future<Family> addMember(String familyId, Member member) async => throw UnimplementedError();
  @override
  Future<Family> addFamily(String displayName) async => throw UnimplementedError();
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
  final List<Session> _savedSnapshots = [];
  List<Session> get savedSnapshots => _savedSnapshots;

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
    throw UnimplementedError();
  }

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {}

  @override
  Future<List<SessionVersion>> history(String sessionId) async {
    return [];
  }

  @override
  Future<List<Session>> loadSessions() async {
    return [];
  }

  @override
  Future<Session?> findSessionById(String id) async {
    if (_savedSnapshots.isEmpty) return null;
    return _savedSnapshots.last;
  }

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    // Simulate network delay to expose race conditions
    await Future.delayed(const Duration(milliseconds: 50));
    final updated = session.copyWith(
      currentVersion: session.currentVersion + 1,
      updatedAt: DateTime.now(),
    );
    _savedSnapshots.add(updated);
    return updated;
  }

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

void main() {
  testWidgets('AttendanceDeckPage allows marking attendance and completes', (
    tester,
  ) async {
    // Setup Data
    final session = Session(
      id: 'session-1',
      title: 'Test Event',
      sessionDate: DateTime.now(),
      records: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'test-user',
    );

    final members = [
      Member(id: '1', displayName: 'Alice'),
      Member(id: '2', displayName: 'Bob'),
    ];

    final mockRepo = MockSessionRepository();

    // build Widget
    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceDeckPage(
          session: session,
          members: members,
          sessionRepository: mockRepo,
          attendanceRepository: MockAttendanceRepository(),
          eventRepository: MockEventRepository(),
          disableAnimations: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify initial state: Alice is shown
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);

    // Tap Present for Alice
    await tester.tap(find.byKey(const Key('presentButton')));
    await tester.pumpAndSettle();

    // Verify Alice is saved
    expect(mockRepo.savedSnapshots.length, 1);
    expect(mockRepo.savedSnapshots.last.records.length, 1);
    expect(mockRepo.savedSnapshots.last.records.first.attendee, 'Alice');
    expect(
      mockRepo.savedSnapshots.last.records.first.status,
      AttendanceStatus.present,
    );

    // Verify Bob is now shown
    expect(find.text('Bob'), findsOneWidget);

    // Tap Absent for Bob
    await tester.tap(find.byKey(const Key('absentButton')));
    await tester.pumpAndSettle();

    // Verify Bob is saved
    expect(mockRepo.savedSnapshots.length, 2);
    expect(mockRepo.savedSnapshots.last.records.length, 2);
    final bobRecord = mockRepo.savedSnapshots.last.records.firstWhere(
      (r) => r.attendee == 'Bob',
    );
    expect(bobRecord.status, AttendanceStatus.absent);

    // Verify Summary Screen
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Test Event'), findsOneWidget);
    expect(find.text('PRESENT', skipOffstage: false), findsWidgets);
  });

  testWidgets('AttendanceDeckPage undo logic works', (tester) async {
    // Setup Data
    final session = Session(
      id: 'session-1',
      title: 'Test Event',
      sessionDate: DateTime.now(),
      records: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'test-user',
    );

    final members = [
      Member(id: '1', displayName: 'Alice'),
      Member(id: '2', displayName: 'Bob'),
    ];

    final mockRepo = MockSessionRepository();

    // build Widget
    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceDeckPage(
          session: session,
          members: members,
          sessionRepository: mockRepo,
          attendanceRepository: MockAttendanceRepository(),
          eventRepository: MockEventRepository(),
          disableAnimations: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    // Tap Present for Alice
    await tester.tap(find.byKey(const Key('presentButton')));
    await tester.pumpAndSettle();

    // Currently seeing Bob
    expect(find.text('Bob'), findsOneWidget);

    // Tap Undo
    await tester.tap(find.byKey(const Key('undoButton')));
    await tester.pumpAndSettle();

    // Verify we are back to Alice
    expect(find.text('Alice'), findsOneWidget);

    // Tap Absent for Alice (change mind)
    await tester.tap(find.byKey(const Key('absentButton')));
    await tester.pumpAndSettle();

    // Verify Alice is saved as absent
    expect(mockRepo.savedSnapshots.last.records.last.attendee, 'Alice');
    expect(
      mockRepo.savedSnapshots.last.records.last.status,
      AttendanceStatus.absent,
    );
  });

  testWidgets('Add Guest functionality works', (tester) async {
    // Setup Data
    final session = Session(
      id: 'session-1',
      title: 'Test Event',
      sessionDate: DateTime.now(),
      records: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'test-user',
    );

    final members = [Member(id: '1', displayName: 'Alice')];

    final mockRepo = MockSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceDeckPage(
          session: session,
          members: members,
          sessionRepository: mockRepo,
          attendanceRepository: MockAttendanceRepository(),
          eventRepository: MockEventRepository(),
          disableAnimations: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify Alice is shown
    expect(find.text('Alice'), findsOneWidget);

    // Tap Add Person
    await tester.tap(find.byTooltip('Add Person'));
    await tester.pumpAndSettle(); // Wait for bottom sheet

    // Verify Sheet is shown
    expect(find.text('Add Person'), findsOneWidget);

    // Enter Name
    await tester.enterText(find.byType(TextField), 'Charlie');
    await tester.pumpAndSettle();

    // Tap Add & Continue
    await tester.tap(find.text('Add & Continue'));
    await tester.pumpAndSettle(); // Wait for sheet to close and save

    // Verify Charlie is saved
    expect(mockRepo.savedSnapshots.isNotEmpty, true);
    final savedSession = mockRepo.savedSnapshots.last;
    final charlieRecord = savedSession.records.firstWhere(
      (r) => r.attendee == 'Charlie',
    );
    expect(
      charlieRecord.status,
      AttendanceStatus.present,
    ); // Default is present

    // Verify we are still on Alice (deck didn't advance)
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets(
    'Last member marked present is preserved in summary despite slow save',
    (tester) async {
      // Setup Data
      final session = Session(
        id: 'session-1',
        title: 'Test Event',
        sessionDate: DateTime.now(),
        records: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'test-user',
      );

      final members = [
        Member(id: '1', displayName: 'Alice'),
        Member(id: '2', displayName: 'Bob'),
      ];

      final mockRepo = MockSessionRepository();

      // build Widget
      await tester.pumpWidget(
        MaterialApp(
          home: AttendanceDeckPage(
            session: session,
            members: members,
            sessionRepository: mockRepo,
            attendanceRepository: MockAttendanceRepository(),
            eventRepository: MockEventRepository(),
            disableAnimations: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // 1. Mark Alice as Present
      await tester.tap(find.byKey(const Key('presentButton')));
      await tester.pumpAndSettle();

      // 2. Mark Bob (LAST MEMBER) as Present
      await tester.tap(find.byKey(const Key('presentButton')));

      // Transition to SessionSummaryPage happens immediately after tapping
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // Verify Stats in Summary: 2 Present
      // In SessionSummaryPage, counts are rendered like Text('${presentMembers.length}')
      expect(find.textContaining('2', skipOffstage: false), findsAtLeastNWidgets(1));

      // Verify both are present in the list
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    },
  );
}
