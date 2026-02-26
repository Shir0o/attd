import 'dart:async';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/presentation/attendance_deck_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockSessionRepository implements SessionRepository {
  final List<Session> _savedSnapshots = [];
  List<Session> get savedSnapshots => _savedSnapshots;

  @override
  Stream<List<Session>> streamSessions({bool includeDeleted = false}) {
    return Stream.value([]);
  }

  @override
  Future<Session> createSession({
    required String title,
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
    return const [];
  }

  @override
  Future<List<Session>> loadSessions({bool includeDeleted = false}) async {
    return const [];
  }

  @override
  Future<Session?> revertToPrevious(
    String sessionId, {
    required String actor,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Session?> restoreToVersion(
    String sessionId,
    int version, {
    required String actor,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    _savedSnapshots.add(session);
    return session;
  }

  @override
  Future<void> refresh() async {}
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
      const Member(id: '1', displayName: 'Alice'),
      const Member(id: '2', displayName: 'Bob'),
    ];

    final mockRepo = MockSessionRepository();

    // build Widget
    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceDeckPage(
          session: session,
          members: members,
          sessionRepository: mockRepo,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
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

    // Verify Completion Screen (Session Summary)
    expect(find.text('Session Summary'), findsOneWidget);
    expect(find.text('Finalize Report'), findsOneWidget);
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
      const Member(id: '1', displayName: 'Alice'),
      const Member(id: '2', displayName: 'Bob'),
    ];

    final mockRepo = MockSessionRepository();

    // build Widget
    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceDeckPage(
          session: session,
          members: members,
          sessionRepository: mockRepo,
        ),
      ),
    );

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

    final members = [const Member(id: '1', displayName: 'Alice')];

    final mockRepo = MockSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceDeckPage(
          session: session,
          members: members,
          sessionRepository: mockRepo,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Verify Alice is shown
    expect(find.text('Alice'), findsOneWidget);

    // Tap Add Guest
    await tester.tap(find.text('Add Guest'));
    await tester.pumpAndSettle(); // Wait for bottom sheet

    // Verify Sheet is shown
    expect(find.text('Guest Name'), findsOneWidget);

    // Enter Guest Name
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
}
