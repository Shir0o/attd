import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/presentation/attendance_deck_page.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/presentation/swipeable_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSessionRepository implements SessionRepository {
  List<Session> savedSessions = [];

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
  Future<Session> duplicate(String sessionId, {required String actor}) {
    throw UnimplementedError();
  }

  @override
  Future<List<SessionVersion>> history(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<Session>> loadSessions({bool includeDeleted = false}) {
    throw UnimplementedError();
  }

  @override
  Future<Session?> revertToPrevious(String sessionId, {required String actor}) {
    throw UnimplementedError();
  }

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    savedSessions.add(session);
    return session;
  }
}

void main() {
  testWidgets('AttendanceDeckPage swipes right to mark present', (
    WidgetTester tester,
  ) async {
    final fakeRepo = FakeSessionRepository();
    final member = const Member(id: '1', displayName: 'Test User');
    final session = Session(
      id: 's1',
      title: 'Test Session',
      sessionDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
      currentVersion: 1,
      records: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceDeckPage(
          session: session,
          members: [member],
          sessionRepository: fakeRepo,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Find the card (SwipeableCard)
    final cardFinder = find.byType(SwipeableCard);
    expect(cardFinder, findsOneWidget);

    // Swipe Right
    await tester.drag(cardFinder, const Offset(300, 0));
    await tester.pump(); // Start animation
    await tester.pumpAndSettle(); // Wait for animation

    // Verify repository was called
    expect(fakeRepo.savedSessions.length, 1);
    final savedRecords = fakeRepo.savedSessions.first.records;
    expect(savedRecords.length, 1);
    expect(savedRecords.first.attendee, 'Test User');
    expect(savedRecords.first.status, AttendanceStatus.present);

    // Verify we are at "Session Summary"
    expect(find.text('Session Summary'), findsOneWidget);
    expect(find.text('Finalize Report'), findsOneWidget);
  });

  testWidgets('AttendanceDeckPage swipes left to mark absent', (
    WidgetTester tester,
  ) async {
    final fakeRepo = FakeSessionRepository();
    final member = const Member(id: '1', displayName: 'Test User');
    final session = Session(
      id: 's1',
      title: 'Test Session',
      sessionDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
      currentVersion: 1,
      records: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceDeckPage(
          session: session,
          members: [member],
          sessionRepository: fakeRepo,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Swipe Left
    await tester.drag(find.byType(SwipeableCard), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(fakeRepo.savedSessions.length, 1);
    expect(
      fakeRepo.savedSessions.first.records.first.status,
      AttendanceStatus.absent,
    );
  });
}
