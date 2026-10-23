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

  @override
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


    test('findDuplicateMembers includes loners, suggests the real family and '
        'reports unlinked marks', () async {
      final realFamily = Family(
        id: 'fam-morelos',
        displayName: 'Morelos',
        members: [
          Member(id: 'm-ana', displayName: 'Ana Morelos'),
          Member(id: 'm-beto', displayName: 'Beto Morelos'),
        ],
      );
      final lonerFamily = Family(
        id: 'fam-ana-loner',
        displayName: 'Ana Morelos',
        isAutoSingleton: true,
        members: [Member(id: 'm-ana-loner', displayName: 'Ana Morelos')],
      );
      // The same member id is also referenced by a leftover auto-singleton.
      final duplicateReference = Family(
        id: 'fam-ana-dup-ref',
        displayName: 'Ana Morelos',
        isAutoSingleton: true,
        members: [Member(id: 'm-ana', displayName: 'Ana Morelos')],
      );
      attRepo.families = [realFamily, lonerFamily, duplicateReference];

      sessionRepo.sessions = [
        Session(
          id: 's-1',
          title: 'Sunday Service',
          sessionDate: DateTime(2026, 5, 20),
          createdAt: now,
          updatedAt: now,
          createdBy: 'Admin',
          records: [
            SessionRecord(
              memberId: 'm-ana',
              attendee: 'Ana Morelos',
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
            SessionRecord(
              memberId: 'm-ana',
              attendee: 'Ana Morelos',
              status: AttendanceStatus.present,
              recordedAt: now,
              recordedBy: 'Admin',
            ),
            SessionRecord(
              memberId: null,
              attendee: 'Ana Morelos',
              status: AttendanceStatus.present,
              recordedAt: now,
              recordedBy: 'Admin',
            ),
          ],
        ),
      ];

      final groups = await service.findDuplicateMembers();

      expect(groups, hasLength(1));
      final group = groups.single;
      expect(group.displayName, 'Ana Morelos');
      expect(group.key, 'ana morelos');
      expect(group.unlinkedMarkCount, 1);
      // The duplicate reference to m-ana is one occurrence, not two.
      expect(group.occurrences, hasLength(2));
      expect(group.occurrences.first.member.id, 'm-ana');
      expect(group.occurrences.first.isLoner, isFalse);
      expect(group.occurrences.first.linkedMarkCount, 2);
      expect(group.occurrences.last.member.id, 'm-ana-loner');
      expect(group.occurrences.last.isLoner, isTrue);
      expect(group.suggestedTarget.member.id, 'm-ana');
    });

    test('simulateMergeMembers and executeMergeMembers merge by id, prune '
        'collisions, and leave same-named other people alone', () async {
      attRepo.families = [
        Family(
          id: 'fam-morelos',
          displayName: 'Morelos',
          members: [
            Member(id: 'm-ana', displayName: 'Ana Morelos'),
          ],
        ),
        Family(
          id: 'fam-ana-loner',
          displayName: 'Ana Morelos',
          isAutoSingleton: true,
          members: [Member(id: 'm-ana-loner', displayName: 'Ana Morelos')],
        ),
      ];

      SessionRecord record(String? memberId, String attendee) => SessionRecord(
            memberId: memberId,
            attendee: attendee,
            status: AttendanceStatus.present,
            recordedAt: now,
            recordedBy: 'Admin',
          );

      sessionRepo.sessions = [
        Session(
          id: 's-target-only',
          title: 'Target Only',
          sessionDate: DateTime(2026, 5, 20),
          createdAt: now,
          updatedAt: now,
          createdBy: 'Admin',
          records: [record('m-ana', 'Ana Morelos')],
        ),
        Session(
          id: 's-collision',
          title: 'Collision',
          sessionDate: DateTime(2026, 5, 21),
          createdAt: now,
          updatedAt: now,
          createdBy: 'Admin',
          records: [
            record('m-ana', 'Ana Morelos'),
            record('m-ana-loner', 'Ana Morelos'),
          ],
        ),
        Session(
          id: 's-source-only',
          title: 'Source Only',
          sessionDate: DateTime(2026, 5, 22),
          createdAt: now,
          updatedAt: now,
          createdBy: 'Admin',
          records: [record('m-ana-loner', 'Ana Morelos')],
        ),
        Session(
          id: 's-other-person',
          title: 'Other Person',
          sessionDate: DateTime(2026, 5, 23),
          createdAt: now,
          updatedAt: now,
          createdBy: 'Admin',
          records: [record('m-ana-other', 'Ana Morelos')],
        ),
        Session(
          id: 's-legacy',
          title: 'Legacy',
          sessionDate: DateTime(2026, 5, 24),
          createdAt: now,
          updatedAt: now,
          createdBy: 'Admin',
          records: [record(null, 'Ana Morelos')],
        ),
      ];

      const plan = MemberMergePlan(
        sourceMemberId: 'm-ana-loner',
        targetMemberId: 'm-ana',
        sourceName: 'Ana Morelos',
        targetName: 'Ana Morelos',
      );

      final dryRun = await service.simulateMergeMembers([plan]);
      expect(dryRun.sessionsAffected, 2);
      expect(dryRun.marksUpdated, 2);
      expect(dryRun.collisionsPruned, 1);
      expect(dryRun.rosterMembersRemoved, 1);
      expect(dryRun.rosterMembersUpdated, 0);

      await service.executeMergeMembers([plan]);

      final morelos = attRepo.families.firstWhere((f) => f.id == 'fam-morelos');
      expect(morelos.members.map((m) => m.id), ['m-ana']);
      final loner = attRepo.families.firstWhere((f) => f.id == 'fam-ana-loner');
      expect(loner.members, isEmpty);

      final collision =
          sessionRepo.sessions.firstWhere((s) => s.id == 's-collision');
      expect(collision.records, hasLength(1));
      expect(collision.records.single.memberId, 'm-ana');

      final sourceOnly =
          sessionRepo.sessions.firstWhere((s) => s.id == 's-source-only');
      expect(sourceOnly.records.single.memberId, 'm-ana');
      expect(sourceOnly.records.single.attendee, 'Ana Morelos');

      final other =
          sessionRepo.sessions.firstWhere((s) => s.id == 's-other-person');
      expect(other.records.single.memberId, 'm-ana-other');

      final legacy =
          sessionRepo.sessions.firstWhere((s) => s.id == 's-legacy');
      expect(legacy.records.single.memberId, isNull);
    });

    test('merge plans reject ambiguous sources and targets', () async {
      const same = MemberMergePlan(
        sourceMemberId: 'm-1',
        targetMemberId: 'm-1',
        sourceName: 'A',
        targetName: 'A',
      );
      await expectLater(
        service.simulateMergeMembers([same]),
        throwsArgumentError,
      );

      const repeatedSource = [
        MemberMergePlan(
          sourceMemberId: 'm-1',
          targetMemberId: 'm-2',
          sourceName: 'A',
          targetName: 'B',
        ),
        MemberMergePlan(
          sourceMemberId: 'm-1',
          targetMemberId: 'm-3',
          sourceName: 'A',
          targetName: 'C',
        ),
      ];
      await expectLater(
        service.simulateMergeMembers(repeatedSource),
        throwsArgumentError,
      );

      const chain = [
        MemberMergePlan(
          sourceMemberId: 'm-1',
          targetMemberId: 'm-2',
          sourceName: 'A',
          targetName: 'B',
        ),
        MemberMergePlan(
          sourceMemberId: 'm-2',
          targetMemberId: 'm-3',
          sourceName: 'B',
          targetName: 'C',
        ),
      ];
      await expectLater(
        service.executeMergeMembers(chain),
        throwsArgumentError,
      );
    });

    group('event title repair', () {
      Session eventSession(
        String id, {
        String? eventId,
        String title = 'Sunday Service',
      }) =>
          Session(
            id: id,
            eventId: eventId,
            title: title,
            sessionDate: DateTime(2026, 5, 20),
            createdAt: now,
            updatedAt: now,
            createdBy: 'Admin',
            records: const [],
          );

      test(
          'previewEventTitleRename splits linked from title-only sessions and '
          'ignores another event', () async {
        sessionRepo.sessions = [
          eventSession('s-linked', eventId: 'event-sunday'),
          eventSession('s-legacy'),
          eventSession('s-other', eventId: 'event-other'),
        ];

        final preview = await service.previewEventTitleRename(
          eventId: 'event-sunday',
          newTitle: 'Sunday Gathering',
          legacyTitle: 'Sunday Service',
        );

        expect(preview.sessionsAffected, 2);
        expect(preview.linkedCount, 1);
        expect(preview.titleOnlyCount, 1);
        expect(preview.sampleLabels, hasLength(2));
        expect(preview.sampleLabels.first, startsWith('Sunday Service · '));
      });

      test(
          'syncs history to the name the event was already renamed to, '
          'matching older sessions by their legacy name', () async {
        // The event was renamed to "Sunday Gathering" on the edit page; its
        // sessions still carry the name they were recorded under.
        sessionRepo.sessions = [
          eventSession('s-linked', eventId: 'event-sunday'),
          eventSession('s-legacy'),
          eventSession('s-legacy-case', title: ' sunday service '),
          eventSession('s-unrelated', title: 'Youth Night'),
          eventSession('s-other', eventId: 'event-other'),
          // Already at the target title: counted as nothing, updatedAt untouched.
          eventSession('s-done',
              eventId: 'event-sunday', title: 'Sunday Gathering'),
        ];

        final changed = await service.executeEventTitleRename(
          eventId: 'event-sunday',
          newTitle: 'Sunday Gathering',
          legacyTitle: 'Sunday Service',
        );

        expect(changed, 3);
        expect(sessionRepo.saveCount, 1);
        String titleOf(String id) =>
            sessionRepo.sessions.firstWhere((s) => s.id == id).title;
        expect(titleOf('s-linked'), 'Sunday Gathering');
        expect(titleOf('s-legacy'), 'Sunday Gathering');
        expect(titleOf('s-legacy-case'), 'Sunday Gathering');
        expect(titleOf('s-unrelated'), 'Youth Night');
        expect(titleOf('s-other'), 'Sunday Service');
        final alreadyRenamed =
            sessionRepo.sessions.firstWhere((s) => s.id == 's-done');
        expect(alreadyRenamed.title, 'Sunday Gathering');
        expect(alreadyRenamed.updatedAt, now);
      });

      test(
          'an event renamed more than once is synced one older name at a time',
          () async {
        // Renamed "Sunday Service" -> "Sunday Worship" -> "Sunday Gathering".
        sessionRepo.sessions = [
          eventSession('s-linked-a', eventId: 'event-sunday'),
          eventSession('s-linked-b',
              eventId: 'event-sunday', title: 'Sunday Worship'),
          eventSession('s-legacy-a'),
          eventSession('s-legacy-b', title: 'Sunday Worship'),
        ];

        final first = await service.executeEventTitleRename(
          eventId: 'event-sunday',
          newTitle: 'Sunday Gathering',
          legacyTitle: 'Sunday Service',
        );
        // Linked sessions sync whatever name they were recorded under.
        expect(first, 3);

        final preview = await service.previewEventTitleRename(
          eventId: 'event-sunday',
          newTitle: 'Sunday Gathering',
          legacyTitle: 'Sunday Worship',
        );
        expect(preview.linkedCount, 0);
        expect(preview.titleOnlyCount, 1);

        final second = await service.executeEventTitleRename(
          eventId: 'event-sunday',
          newTitle: 'Sunday Gathering',
          legacyTitle: 'Sunday Worship',
        );
        expect(second, 1);
        expect(
          sessionRepo.sessions.map((s) => s.title),
          everyElement('Sunday Gathering'),
        );
      });

      test('leaves title-only sessions alone when no legacy name is given',
          () async {
        sessionRepo.sessions = [
          eventSession('s-linked', eventId: 'event-sunday'),
          eventSession('s-legacy'),
        ];

        final changed = await service.executeEventTitleRename(
          eventId: 'event-sunday',
          newTitle: 'Sunday Gathering',
          legacyTitle: '  ',
        );

        expect(changed, 1);
        expect(
          sessionRepo.sessions.firstWhere((s) => s.id == 's-linked').title,
          'Sunday Gathering',
        );
        expect(
          sessionRepo.sessions.firstWhere((s) => s.id == 's-legacy').title,
          'Sunday Service',
        );
      });

      test('writes nothing when every session already has the name', () async {
        sessionRepo.sessions = [
          eventSession('s-linked',
              eventId: 'event-sunday', title: 'Sunday Gathering'),
        ];

        final changed = await service.executeEventTitleRename(
          eventId: 'event-sunday',
          newTitle: 'Sunday Gathering',
        );

        expect(changed, 0);
        expect(sessionRepo.saveCount, 0);
      });

      test('rejects a blank new name or a missing event id', () async {
        await expectLater(
          service.executeEventTitleRename(
            eventId: 'event-sunday',
            newTitle: '   ',
          ),
          throwsArgumentError,
        );
        await expectLater(
          service.previewEventTitleRename(eventId: ' ', newTitle: 'X'),
          throwsArgumentError,
        );
      });
    });

    test('BulkDryRunResult totalOperations computes correctly', () {
      const result = BulkDryRunResult(
        sessionsAffected: 2,
        marksUpdated: 5,
        collisionsPruned: 1,
        rosterMembersUpdated: 2,
        rosterMembersRemoved: 1,
        affectedSessionTitles: ['Session A', 'Session B'],
      );
      expect(result.totalOperations, 5 + 1 + 2 + 1);
    });
  });
}
