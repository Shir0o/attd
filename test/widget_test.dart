import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _ImmediateSessionRepository implements SessionRepository {
  _ImmediateSessionRepository(this.sessions);

  final List<Session> sessions;

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
    return sessions.first;
  }

  @override
  Future<List<SessionVersion>> history(String sessionId) async {
    return const [];
  }

  @override
  Future<List<Session>> loadSessions({bool includeDeleted = false}) async {
    return sessions;
  }

  @override
  Future<Session?> revertToPrevious(
    String sessionId, {
    required String actor,
  }) async {
    return sessions.first;
  }

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    return session;
  }
}

void main() {
  testWidgets('Shows analytics overview and actions', (tester) async {
    sqfliteFfiInit();

    final sessionRepository = _ImmediateSessionRepository(buildSeedSessions());

    await tester.pumpWidget(
      AttendanceApp(
        repository: LocalJsonAttendanceRepository(),
        sessionRepository: sessionRepository,
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Engagement overview'), findsOneWidget);
    expect(find.text('Wellness watchlist'), findsOneWidget);
    expect(find.text('Drill-down insights'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Take attendance'), findsOneWidget);
    expect(find.text('Attendance rate'), findsWidgets);
    expect(find.text('Recent sessions'), findsOneWidget);
  });
}
