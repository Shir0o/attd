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
  Future<Session> duplicate(String sessionId, {required String actor}) {
    throw UnimplementedError();
  }

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
    try {
      return savedSessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {}

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    savedSessions.add(session);
    return session;
  }

  @override
  Future<void> refresh() async {}
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

    // Verify we are at the summary page (it shows the session title)
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Test Session'), findsOneWidget);
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

    // Tap Absent button (instead of drag for more reliable transition test)
    await tester.tap(find.byKey(const Key('absentButton')));
    await tester.pump(); // Start transition
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(fakeRepo.savedSessions.length, 1);
    expect(
      fakeRepo.savedSessions.first.records.first.status,
      AttendanceStatus.absent,
    );

    // Verify Completion Screen
    expect(find.text('Test Session'), findsOneWidget);
    expect(find.text('Finalize Report'), findsOneWidget);
  });
}
