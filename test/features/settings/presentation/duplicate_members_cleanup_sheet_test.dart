import 'package:attendance_tracker/data/local_session_repository.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/settings/presentation/duplicate_members_cleanup_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AttendanceRepository extends LocalJsonAttendanceRepository {
  _AttendanceRepository(this.families);

  List<Family> families;
  int saveCount = 0;

  @override
  Future<List<Family>> fetchAllFamilies() async => families;

  @override
  Future<List<Family>> fetchFamilies() async => families;

  @override
  Future<void> saveFamilies(List<Family> families) async {
    saveCount++;
    this.families = families;
  }

  @override
  Future<Family> addFamily(String displayName,
      {bool isAutoSingleton = false}) async {
    throw UnimplementedError();
  }

  @override
  Future<Family> addMember(String familyId, Member member) async {
    throw UnimplementedError();
  }

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<void> refresh() async {}

  @override
  Stream<List<Family>> streamFamilies() => Stream.value(families);
}

class _SessionRepository extends LocalJsonSessionRepository {
  _SessionRepository(this.sessions);

  List<Session> sessions;
  int saveCount = 0;

  @override
  Future<List<Session>> fetchAllSessions() async => sessions;

  @override
  Future<List<Session>> loadSessions() async => sessions;

  @override
  Future<void> saveSessions(List<Session> sessions) async {
    saveCount++;
    this.sessions = sessions;
  }

  @override
  Future<List<SessionVersion>> history(String sessionId) async => [];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final now = DateTime(2026, 5, 1, 10);

  SessionRecord record(String? memberId, String attendee) => SessionRecord(
        memberId: memberId,
        attendee: attendee,
        status: AttendanceStatus.present,
        recordedAt: now,
        recordedBy: 'Admin',
      );

  Widget host({
    required _AttendanceRepository attendance,
    required _SessionRepository sessions,
    required Future<void> Function() onComplete,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDuplicateMembersCleanupSheet(
                context: context,
                attendanceRepository: attendance,
                sessionRepository: sessions,
                onComplete: onComplete,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('suggests a loner duplicate, previews the merge and applies it',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final attendance = _AttendanceRepository([
      Family(
        id: 'fam-morelos',
        displayName: 'Morelos',
        members: [Member(id: 'm-ana', displayName: 'Ana Morelos')],
        updatedAt: now,
      ),
      Family(
        id: 'fam-loner',
        displayName: 'Ana Morelos',
        isAutoSingleton: true,
        members: [Member(id: 'm-ana-loner', displayName: 'Ana Morelos')],
        updatedAt: now,
      ),
    ]);
    final sessions = _SessionRepository([
      Session(
        id: 's-target',
        title: 'Target Only',
        sessionDate: DateTime(2026, 5, 2),
        createdAt: now,
        updatedAt: now,
        createdBy: 'Admin',
        records: [record('m-ana', 'Ana Morelos')],
      ),
      Session(
        id: 's-collision',
        title: 'Collision',
        sessionDate: DateTime(2026, 5, 3),
        createdAt: now,
        updatedAt: now,
        createdBy: 'Admin',
        records: [
          record('m-ana', 'Ana Morelos'),
          record('m-ana-loner', 'Ana Morelos'),
        ],
      ),
    ]);

    var completed = 0;
    await tester.pumpWidget(host(
      attendance: attendance,
      sessions: sessions,
      onComplete: () async => completed++,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Duplicate cleanup'), findsOneWidget);
    expect(find.text('Ana Morelos'), findsOneWidget);
    expect(find.text('Morelos'), findsOneWidget);
    expect(find.text('Loner'), findsOneWidget);
    expect(find.textContaining('ID m-ana'), findsWidgets);

    // The group starts as "Keep both"; including it opts into the merge.
    await tester.tap(
      find.byKey(const ValueKey('duplicate_include_ana morelos')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('duplicate_cleanup_dry_run')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('duplicate_cleanup_results')),
      findsOneWidget,
    );
    expect(find.text('Duplicate profiles removed:'), findsOneWidget);
    expect(find.text('Past sessions affected:'), findsOneWidget);
    expect(find.text('Intra-session collisions pruned:'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('duplicate_cleanup_apply')));
    await tester.pumpAndSettle();

    expect(completed, 1);
    expect(find.text('Duplicate cleanup'), findsNothing);
    expect(attendance.saveCount, 1);
    expect(sessions.saveCount, 1);

    final morelos =
        attendance.families.firstWhere((f) => f.id == 'fam-morelos');
    expect(morelos.members.map((m) => m.id), ['m-ana']);
    final loner = attendance.families.firstWhere((f) => f.id == 'fam-loner');
    expect(loner.members, isEmpty);

    final collision =
        sessions.sessions.firstWhere((s) => s.id == 's-collision');
    expect(collision.records, hasLength(1));
    expect(collision.records.single.memberId, 'm-ana');
  });

  testWidgets('dismissing a suggestion hides it and persists on this device',
      (tester) async {
    final attendance = _AttendanceRepository([
      Family(
        id: 'fam-1',
        displayName: 'Morelos',
        members: [Member(id: 'm-ana', displayName: 'Ana Morelos')],
        updatedAt: now,
      ),
      Family(
        id: 'fam-2',
        displayName: 'Ana Morelos',
        isAutoSingleton: true,
        members: [Member(id: 'm-ana-loner', displayName: 'Ana Morelos')],
        updatedAt: now,
      ),
    ]);

    await tester.pumpWidget(host(
      attendance: attendance,
      sessions: _SessionRepository([]),
      onComplete: () async {},
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('duplicate_dismiss_ana morelos')),
    );
    await tester.pumpAndSettle();

    expect(find.text('No duplicate names found.'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('duplicate_member_suggestions_dismissed'),
      ['ana morelos'],
    );
  });

  testWidgets('shows an empty state when nothing shares a name',
      (tester) async {
    final attendance = _AttendanceRepository([
      Family(
        id: 'fam-1',
        displayName: 'Morelos',
        members: [Member(id: 'm-ana', displayName: 'Ana Morelos')],
        updatedAt: now,
      ),
    ]);

    await tester.pumpWidget(host(
      attendance: attendance,
      sessions: _SessionRepository([]),
      onComplete: () async {},
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('No duplicate names found.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('duplicate_cleanup_dry_run')),
      findsNothing,
    );
  });
}
