import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/core/maintenance/bulk_maintenance_service.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/data/local_session_repository.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';

class _MockAttendanceRepository extends AttendanceRepository {
  _MockAttendanceRepository(this.families);

  List<Family> families;
  int saveCount = 0;

  @override
  Future<List<Family>> fetchFamilies() async => families;

  Future<List<Family>> fetchAllFamilies() async => families;

  @override
  Future<void> saveFamilies(List<Family> updated) async {
    saveCount++;
    families = updated;
  }

  @override
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) =>
      throw UnimplementedError();

  @override
  Future<Family> addMember(String familyId, Member member) =>
      throw UnimplementedError();

  @override
  Future<Family> moveMemberToFamily(String memberId, String targetFamilyId) =>
      throw UnimplementedError();

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<void> refresh() async {}

  @override
  Stream<List<Family>> streamFamilies() => Stream.value(families);
}

class _MockSessionRepository extends LocalJsonSessionRepository {
  _MockSessionRepository(this.sessions);

  List<Session> sessions;
  int saveCount = 0;

  @override
  Future<List<Session>> fetchAllSessions() async => sessions;

  @override
  Future<List<Session>> loadSessions() async => sessions;

  @override
  Future<void> saveSessions(List<Session> updated) async {
    saveCount++;
    sessions = updated;
  }

  @override
  Future<List<SessionVersion>> history(String sessionId) async => [];
}

void main() {
  group('BulkMaintenanceService', () {
    late _MockAttendanceRepository attRepo;
    late _MockSessionRepository sessionRepo;
    late BulkMaintenanceService service;

    final now = DateTime(2026, 6, 1, 10, 0);

    setUp(() {
      attRepo = _MockAttendanceRepository([
        Family(
          id: 'fam-1',
          displayName: 'Smith Family',
          members: [
            Member(id: 'm-bob', displayName: 'Bob Smith'),
          ],
        ),
        Family(
          id: 'fam-2',
          displayName: 'Smith Household',
          members: [
            Member(id: 'm-robert', displayName: 'Robert Smith'),
          ],
        ),
      ]);

      sessionRepo = _MockSessionRepository([
        Session(
          id: 's-1',
          title: 'Sunday Service',
          sessionDate: DateTime(2026, 5, 20),
          createdAt: now,
          updatedAt: now,
          createdBy: 'Admin',
          records: [
            SessionRecord(
              memberId: 'm-bob',
              attendee: 'Bob Smith',
              status: AttendanceStatus.present,
              recordedAt: now,
              recordedBy: 'Admin',
            ),
          ],
        ),
        Session(
          id: 's-2',
          title: 'Bible Study',
          sessionDate: DateTime(2026, 5, 27),
          createdAt: now,
          updatedAt: now,
          createdBy: 'Admin',
          records: [
            // Collision session: both Bob and Robert were recorded
            SessionRecord(
              memberId: 'm-bob',
              attendee: 'Bob Smith',
              status: AttendanceStatus.present,
              recordedAt: now,
              recordedBy: 'Admin',
            ),
            SessionRecord(
              memberId: 'm-robert',
              attendee: 'Robert Smith',
              status: AttendanceStatus.present,
              recordedAt: now,
              recordedBy: 'Admin',
            ),
          ],
        ),
        Session(
          id: 's-3',
          title: 'Youth Night',
          sessionDate: DateTime(2026, 5, 28),
          createdAt: now,
          updatedAt: now,
          createdBy: 'Admin',
          records: [
            // Legacy unlinked mark
            SessionRecord(
              memberId: null,
              attendee: 'Bob Smith',
              status: AttendanceStatus.present,
              recordedAt: now,
              recordedBy: 'Admin',
            ),
          ],
        ),
      ]);

      service = BulkMaintenanceService(
        attendanceRepository: attRepo,
        sessionRepository: sessionRepo,
      );
    });

    test('dryRunMerge accurately reports affected counts and collisions', () async {
      final dryRun = await service.simulateMerge(
        sourceIdentifier: 'm-bob',
        sourceName: 'Bob Smith',
        targetMemberId: 'm-robert',
        targetName: 'Robert Smith',
        updateRoster: true,
      );

      expect(dryRun.sessionsAffected, 3);
      expect(dryRun.marksUpdated, 3); // 2 in s-1 and s-3, 1 in s-2 (which collides and prunes)
      expect(dryRun.collisionsPruned, 1); // s-2 had both
      expect(dryRun.rosterMembersRemoved, 1);
      expect(dryRun.rosterMembersUpdated, 0);
    });

    test('executeMerge performs merge across roster and sessions and prunes collisions', () async {
      await service.executeMerge(
        sourceIdentifier: 'm-bob',
        sourceName: 'Bob Smith',
        targetMemberId: 'm-robert',
        targetName: 'Robert Smith',
        updateRoster: true,
      );

      expect(attRepo.saveCount, 1);
      expect(sessionRepo.saveCount, 1);

      // Verify roster
      final f1 = attRepo.families.firstWhere((f) => f.id == 'fam-1');
      expect(f1.members.any((m) => m.id == 'm-bob'), isFalse);

      final f2 = attRepo.families.firstWhere((f) => f.id == 'fam-2');
      expect(f2.members.any((m) => m.id == 'm-robert'), isTrue);

      // Verify s-1: Bob Smith updated to Robert Smith
      final s1 = sessionRepo.sessions.firstWhere((s) => s.id == 's-1');
      expect(s1.records.length, 1);
      expect(s1.records.first.attendee, 'Robert Smith');
      expect(s1.records.first.memberId, 'm-robert');

      // Verify s-2: Collision pruned, only 1 record for Robert Smith remains
      final s2 = sessionRepo.sessions.firstWhere((s) => s.id == 's-2');
      expect(s2.records.length, 1);
      expect(s2.records.first.attendee, 'Robert Smith');
      expect(s2.records.first.memberId, 'm-robert');

      // Verify s-3: Unlinked Bob Smith linked and renamed to Robert Smith
      final s3 = sessionRepo.sessions.firstWhere((s) => s.id == 's-3');
      expect(s3.records.length, 1);
      expect(s3.records.first.attendee, 'Robert Smith');
      expect(s3.records.first.memberId, 'm-robert');
    });

    test('simulateRename and executeRename updates name across sessions and roster without deleting member', () async {
      final dryRun = await service.simulateRename(
        oldName: 'Bob Smith',
        newName: 'Bobby Smith',
        memberId: 'm-bob',
        updateRoster: true,
      );

      expect(dryRun.sessionsAffected, 3);
      expect(dryRun.marksUpdated, 3);
      expect(dryRun.collisionsPruned, 0);
      expect(dryRun.rosterMembersUpdated, 1);

      await service.executeRename(
        oldName: 'Bob Smith',
        newName: 'Bobby Smith',
        memberId: 'm-bob',
        updateRoster: true,
      );

      final f1 = attRepo.families.firstWhere((f) => f.id == 'fam-1');
      expect(f1.members.firstWhere((m) => m.id == 'm-bob').displayName, 'Bobby Smith');

      final s1 = sessionRepo.sessions.firstWhere((s) => s.id == 's-1');
      expect(s1.records.first.attendee, 'Bobby Smith');
    });
  });
}
