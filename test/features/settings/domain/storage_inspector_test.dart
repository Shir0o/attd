import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/features/settings/domain/storage_inspector.dart';

class _FakeAttendanceRepo extends AttendanceRepository {
  _FakeAttendanceRepo(this.families);
  List<Family> families;
  int saveCount = 0;

  @override
  Future<List<Family>> fetchAllFamilies() async => families;

  @override
  Future<List<Family>> fetchFamilies() async =>
      families.where((f) => f.deletedAt == null).toList();

  @override
  Future<void> saveFamilies(List<Family> updated) async {
    saveCount++;
    families = List.from(updated);
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

class _FakeEventRepo extends EventRepository {
  _FakeEventRepo(this.events);
  List<Event> events;
  int saveCount = 0;

  @override
  Future<List<Event>> fetchAllEvents() async => events;

  @override
  Future<void> saveEvents(List<Event> updated) async {
    saveCount++;
    events = List.from(updated);
  }

  @override
  Future<void> createEvent(Event event) => throw UnimplementedError();

  @override
  Future<void> updateEvent(Event event) => throw UnimplementedError();

  @override
  Future<void> deleteEvent(String eventId) => throw UnimplementedError();

  @override
  Future<Event?> findEventById(String eventId) async =>
      events.where((e) => e.id == eventId).firstOrNull;

  @override
  Stream<List<Event>> streamEvents() => Stream.value(events);

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class _FakeSessionRepo extends SessionRepository {
  _FakeSessionRepo(this.sessions);
  List<Session> sessions;
  int saveCount = 0;

  @override
  Future<List<Session>> fetchAllSessions() async => sessions;

  @override
  Future<List<Session>> loadSessions() async =>
      sessions.where((s) => s.deletedAt == null).toList();

  @override
  Future<void> saveSessions(List<Session> updated) async {
    saveCount++;
    sessions = List.from(updated);
  }

  @override
  Future<Session> createSession({
    required String title,
    String? eventId,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteSession(String sessionId, {required String actor}) =>
      throw UnimplementedError();

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) =>
      throw UnimplementedError();

  @override
  Future<Session?> findSessionById(String id) async =>
      sessions.where((s) => s.id == id).firstOrNull;

  @override
  Future<List<SessionVersion>> history(String sessionId) async => [];

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) =>
      throw UnimplementedError();

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) =>
      throw UnimplementedError();

  @override
  Stream<List<Session>> streamSessions() => Stream.value(sessions);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final baseDate = DateTime(2026, 4, 1, 10, 0);

  late _FakeAttendanceRepo attRepo;
  late _FakeEventRepo eventRepo;
  late _FakeSessionRepo sessionRepo;
  late StorageInspector inspector;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    attRepo = _FakeAttendanceRepo([
      Family(
        id: 'fam-live',
        displayName: 'Smiths',
        updatedAt: baseDate,
        members: [
          Member(
            id: 'm-alice',
            displayName: 'Alice Smith',
            updatedAt: baseDate,
          ),
          Member(
            id: 'm-bob-dead',
            displayName: 'Bob Smith',
            updatedAt: baseDate,
            deletedAt: baseDate,
          ),
        ],
      ),
      Family(
        id: 'fam-dead',
        displayName: 'Oldies',
        updatedAt: baseDate,
        deletedAt: baseDate,
        members: [
          Member(
            id: 'm-charlie',
            displayName: 'Charlie Old',
            updatedAt: baseDate,
          ),
        ],
      ),
      Family(
        id: 'fam-empty',
        displayName: 'Empty House',
        updatedAt: baseDate,
        members: [],
      ),
      // duplicate member ID across families test
      Family(
        id: 'fam-dup',
        displayName: 'Duplicate Clan',
        updatedAt: baseDate,
        members: [
          Member(
            id: 'm-alice', // duplicate of m-alice in fam-live
            displayName: 'Alice Smith Dup',
            updatedAt: baseDate,
          ),
        ],
      ),
    ]);

    eventRepo = _FakeEventRepo([
      Event(
        id: 'evt-weekly',
        title: 'Weekly Sunday',
        frequency: 'Weekly',
        repeatingDays: ['Sunday'],
        time: const TimeOfDay(hour: 10, minute: 30),
        createdAt: baseDate,
        updatedAt: baseDate,
        memberIds: ['m-alice'],
      ),
      Event(
        id: 'evt-freq-only',
        title: 'Monthly Feast',
        frequency: 'Monthly',
        repeatingDays: [],
        time: const TimeOfDay(hour: 18, minute: 0),
        createdAt: baseDate,
        updatedAt: baseDate,
      ),
      Event(
        id: 'evt-dead',
        title: 'Cancelled Class',
        frequency: 'Weekly',
        repeatingDays: ['Monday'],
        time: const TimeOfDay(hour: 9, minute: 0),
        createdAt: baseDate,
        updatedAt: baseDate,
        deletedAt: baseDate,
      ),
    ]);

    sessionRepo = _FakeSessionRepo([
      Session(
        id: 'ses-live-1',
        title: 'Weekly Sunday',
        eventId: 'evt-weekly',
        sessionDate: baseDate,
        createdAt: baseDate,
        updatedAt: baseDate,
        createdBy: 'admin',
        records: [
          SessionRecord(
            memberId: 'm-alice',
            attendee: 'Alice Smith',
            status: AttendanceStatus.present,
            recordedAt: baseDate,
            recordedBy: 'admin',
          ),
          SessionRecord(
            memberId: 'm-orphan', // does not exist in active members
            attendee: 'Orphan Dan',
            status: AttendanceStatus.absent,
            recordedAt: baseDate.add(const Duration(minutes: 5)),
            recordedBy: 'admin',
          ),
          SessionRecord(
            memberId: 'm-alice',
            attendee: 'Alice Smith', // duplicate entry in same event/date
            status: AttendanceStatus.present,
            recordedAt: baseDate.add(const Duration(minutes: 10)),
            recordedBy: 'admin',
          ),
          SessionRecord(
            attendee: 'Guest Gary', // guest mark with no memberId
            status: AttendanceStatus.present,
            recordedAt: baseDate.add(const Duration(minutes: 15)),
            recordedBy: 'admin',
          ),
        ],
      ),
      Session(
        id: 'ses-live-2',
        title: 'Weekly Sunday',
        eventId: 'evt-weekly',
        sessionDate: baseDate, // sibling of ses-live-1
        createdAt: baseDate,
        updatedAt: baseDate,
        createdBy: 'admin',
        records: [
          SessionRecord(
            memberId: 'm-alice',
            attendee: 'Alice Smith',
            status: AttendanceStatus.present,
            recordedAt: baseDate.add(const Duration(hours: 1)),
            recordedBy: 'admin',
          ),
        ],
      ),
      Session(
        id: 'ses-dead',
        title: 'Weekly Sunday',
        eventId: 'evt-weekly',
        sessionDate: baseDate,
        createdAt: baseDate,
        updatedAt: baseDate,
        createdBy: 'admin',
        deletedAt: baseDate,
        records: [
          SessionRecord(
            memberId: 'm-alice',
            attendee: 'Alice Smith',
            status: AttendanceStatus.present,
            recordedAt: baseDate,
            recordedBy: 'admin',
          ),
        ],
      ),
      Session(
        id: 'ses-orphan-event',
        title: 'Ghost Event Session',
        eventId: 'evt-non-existent',
        sessionDate: baseDate,
        createdAt: baseDate,
        updatedAt: baseDate,
        createdBy: 'admin',
        records: [
          SessionRecord(
            memberId: 'm-alice',
            attendee: 'Alice Smith',
            status: AttendanceStatus.present,
            recordedAt: baseDate,
            recordedBy: 'admin',
          ),
        ],
      ),
      Session(
        id: 'ses-empty',
        title: 'Empty Session',
        eventId: 'evt-weekly',
        sessionDate: baseDate,
        createdAt: baseDate,
        updatedAt: baseDate,
        createdBy: 'admin',
        records: [],
      ),
    ]);

    inspector = StorageInspector(
      attendanceRepository: attRepo,
      eventRepository: eventRepo,
      sessionRepository: sessionRepo,
    );
  });

  group('Diagnostic scanning and DbRecord categorization', () {
    test('scans repositories and builds accurate records and review suggestions', () async {
      await inspector.scan();

      expect(inspector.families.length, 4);
      expect(inspector.events.length, 3);
      expect(inspector.sessions.length, 5);

      // Verify member usage map tracks active sessions only
      final aliceUsage = inspector.memberUsageMap['m-alice'];
      expect(aliceUsage, isNotNull);
      // ses-live-1 (2 marks), ses-live-2 (1 mark), ses-orphan-event (1 mark); ses-dead is skipped
      expect(aliceUsage!.length, 4);

      // Tombstones
      final tombstones = inspector.tombstones;
      expect(tombstones.any((r) => r.id == 'evt-dead' && r.table == 'events'), isTrue);
      expect(tombstones.any((r) => r.id == 'ses-dead' && r.table == 'sessions'), isTrue);
      expect(tombstones.any((r) => r.id == 'fam-dead' && r.table == 'families'), isTrue);
      expect(tombstones.any((r) => r.id == 'm-bob-dead' && r.table == 'members'), isTrue);
      expect(tombstones.any((r) => r.id == 'm-charlie' && r.table == 'members'), isTrue);

      // Orphaned records
      final orphans = inspector.orphanedRecords;
      expect(orphans.any((r) => r.id == 'fam-empty' && r.table == 'families'), isTrue);
      expect(orphans.any((r) => r.id == 'ses-orphan-event' && r.table == 'sessions'), isTrue);
      expect(orphans.any((r) => r.id == 'ses-empty' && r.table == 'sessions'), isTrue);
      // Orphan mark
      expect(
        orphans.any((r) =>
            r.table == 'attendance' &&
            r.fields['member_id'] == 'm-orphan' &&
            r.flag == 'orphan'),
        isTrue,
      );

      // Duplicate marks
      final duplicates = inspector.duplicateMarks;
      expect(
        duplicates.any((r) =>
            r.table == 'attendance' &&
            r.fields['attendee'] == 'Alice Smith' &&
            r.flag == 'duplicate'),
        isTrue,
      );

      // Review suggestions contain both orphans and duplicates
      expect(inspector.reviewSuggestions.length, greaterThanOrEqualTo(5));
      for (final s in inspector.reviewSuggestions) {
        expect(s.isIssue, isTrue);
        expect(inspector.needsReview(s), isTrue);
      }
    });

    test('dismissing and un-dismissing review suggestions persists state', () async {
      await inspector.scan();

      final firstSuggestion = inspector.reviewSuggestions.first;
      final key = firstSuggestion.uniqueKey;

      expect(inspector.isDismissed(key), isFalse);
      expect(inspector.needsReview(firstSuggestion), isTrue);

      await inspector.setDismissed(firstSuggestion, true);

      expect(inspector.isDismissed(key), isTrue);
      expect(inspector.needsReview(firstSuggestion), isFalse);
      expect(inspector.dismissedKeys.contains(key), isTrue);

      // Un-dismiss
      await inspector.setDismissed(firstSuggestion, false);
      expect(inspector.isDismissed(key), isFalse);
      expect(inspector.needsReview(firstSuggestion), isTrue);

      // Re-scan loads dismissed keys
      await inspector.setDismissedByKey(key, true);
      final newInspector = StorageInspector(
        attendanceRepository: attRepo,
        eventRepository: eventRepo,
        sessionRepository: sessionRepo,
      );
      await newInspector.scan();
      expect(newInspector.isDismissed(key), isTrue);
    });
  });

  group('InspectorIndex lookups', () {
    test('provides accurate lookups for sessions, events, siblings, and members', () async {
      await inspector.scan();
      final index = inspector.index;

      expect(index.session('ses-live-1')?.title, 'Weekly Sunday');
      expect(index.session('non-existent'), isNull);

      expect(index.event('evt-weekly')?.title, 'Weekly Sunday');
      expect(index.event('non-existent'), isNull);

      final liveSession1 = inspector.sessions.firstWhere((s) => s.id == 'ses-live-1');
      final siblings = index.siblings(liveSession1);
      expect(siblings.length, 1);
      expect(siblings.first.id, 'ses-live-2');

      expect(index.isLiveMember('m-alice'), isTrue);
      expect(index.isLiveMember('m-bob-dead'), isFalse);
      expect(index.isLiveMember('m-charlie'), isFalse);
      expect(index.isLiveMember('m-non-existent'), isFalse);

      final named = index.liveMembersNamed('alice smith');
      expect(named.length, 1);
      expect(named.first.$1.id, 'm-alice');
      expect(named.first.$2.id, 'fam-live');
    });
  });

  group('InspectorDraft and Mutations', () {
    test('InspectorDraft puts and removes entities cleanly', () {
      final draft = InspectorDraft(
        inspector.events,
        inspector.sessions,
        inspector.families,
      );

      final newEvent = Event(
        id: 'evt-new',
        title: 'New',
        frequency: 'Daily',
        time: const TimeOfDay(hour: 12, minute: 0),
        createdAt: baseDate,
        updatedAt: baseDate,
      );
      draft.putEvent(newEvent);
      expect(draft.events.any((e) => e.id == 'evt-new'), isTrue);
      expect(draft.touchedEvents.contains('evt-new'), isTrue);

      draft.removeEvent('evt-new');
      expect(draft.events.any((e) => e.id == 'evt-new'), isFalse);

      final newSession = Session(
        id: 'ses-new',
        title: 'New',
        sessionDate: baseDate,
        createdAt: baseDate,
        updatedAt: baseDate,
        createdBy: 'test',
        records: [],
      );
      draft.putSession(newSession);
      expect(draft.sessions.any((s) => s.id == 'ses-new'), isTrue);
      expect(draft.touchedSessions.contains('ses-new'), isTrue);

      draft.removeSession('ses-new');
      expect(draft.sessions.any((s) => s.id == 'ses-new'), isFalse);

      final newFam = Family(id: 'fam-new', displayName: 'New Fam', members: []);
      draft.putFamily(newFam);
      expect(draft.families.any((f) => f.id == 'fam-new'), isTrue);
      expect(draft.touchedFamilies.contains('fam-new'), isTrue);

      draft.removeFamily('fam-new');
      expect(draft.families.any((f) => f.id == 'fam-new'), isFalse);
    });

    test('mutations track touch state and support undo', () async {
      await inspector.scan();
      expect(inspector.canUndo, isFalse);

      // Perform a mutation
      await inspector.mutate((d) {
        final evt = d.events.firstWhere((e) => e.id == 'evt-weekly');
        d.putEvent(evt.copyWith(title: 'Updated Sunday'));
      });

      expect(inspector.canUndo, isTrue);
      expect(inspector.events.firstWhere((e) => e.id == 'evt-weekly').title, 'Updated Sunday');

      // Undo mutation
      await inspector.undo();
      expect(inspector.canUndo, isFalse);
      expect(inspector.events.firstWhere((e) => e.id == 'evt-weekly').title, 'Weekly Sunday');

      // Undo when canUndo is false is safe no-op
      await inspector.undo();
      expect(inspector.canUndo, isFalse);
    });
  });

  group('Record deletion and restoration', () {
    test('soft-deletes active records and permanently deletes tombstones', () async {
      await inspector.scan();

      // Active event -> soft deleted
      final activeEventRecord = inspector.allRecords.firstWhere((r) => r.id == 'evt-weekly');
      await inspector.deleteRecord(activeEventRecord);
      expect(eventRepo.events.firstWhere((e) => e.id == 'evt-weekly').deletedAt, isNotNull);

      // Tombstone event -> permanently removed
      final deadEventRecord = inspector.allRecords.firstWhere((r) => r.id == 'evt-dead');
      await inspector.deleteRecord(deadEventRecord);
      expect(eventRepo.events.any((e) => e.id == 'evt-dead'), isFalse);

      // Active session -> soft deleted
      final activeSessionRecord = inspector.allRecords.firstWhere((r) => r.id == 'ses-live-1');
      await inspector.deleteRecord(activeSessionRecord);
      expect(sessionRepo.sessions.firstWhere((s) => s.id == 'ses-live-1').deletedAt, isNotNull);

      // Tombstone session -> permanently removed
      final deadSessionRecord = inspector.allRecords.firstWhere((r) => r.id == 'ses-dead');
      await inspector.deleteRecord(deadSessionRecord);
      expect(sessionRepo.sessions.any((s) => s.id == 'ses-dead'), isFalse);

      // Active family -> soft deleted
      final activeFamilyRecord = inspector.allRecords.firstWhere((r) => r.id == 'fam-live');
      await inspector.deleteRecord(activeFamilyRecord);
      expect(attRepo.families.firstWhere((f) => f.id == 'fam-live').deletedAt, isNotNull);

      // Tombstone family -> permanently removed
      final deadFamilyRecord = inspector.allRecords.firstWhere((r) => r.id == 'fam-dead');
      await inspector.deleteRecord(deadFamilyRecord);
      expect(attRepo.families.any((f) => f.id == 'fam-dead'), isFalse);

      // Active member -> soft deleted
      final activeMemberRecord = inspector.allRecords.firstWhere((r) => r.id == 'm-alice');
      await inspector.deleteRecord(activeMemberRecord);
      final aliceInFam = attRepo.families
          .expand((f) => f.members)
          .firstWhere((m) => m.id == 'm-alice');
      expect(aliceInFam.deletedAt, isNotNull);

      // Tombstone member -> permanently removed
      final deadMemberRecord = inspector.allRecords.firstWhere((r) => r.id == 'm-bob-dead');
      await inspector.deleteRecord(deadMemberRecord);
      expect(
        attRepo.families.expand((f) => f.members).any((m) => m.id == 'm-bob-dead'),
        isFalse,
      );

      // Attendance mark deletion -> removed from session
      final markRecord = inspector.allRecords.firstWhere(
        (r) => r.table == 'attendance' && r.fields['member_id'] == 'm-orphan',
      );
      await inspector.deleteRecord(markRecord);
      final s1 = sessionRepo.sessions.firstWhere((s) => s.id == 'ses-live-1');
      expect(s1.records.any((r) => r.memberId == 'm-orphan'), isFalse);
    });

    test('restores soft-deleted tombstones', () async {
      await inspector.scan();

      final deadEventRecord = inspector.allRecords.firstWhere((r) => r.id == 'evt-dead');
      await inspector.restoreRecord(deadEventRecord);
      expect(eventRepo.events.firstWhere((e) => e.id == 'evt-dead').deletedAt, isNull);

      final deadSessionRecord = inspector.allRecords.firstWhere((r) => r.id == 'ses-dead');
      await inspector.restoreRecord(deadSessionRecord);
      expect(sessionRepo.sessions.firstWhere((s) => s.id == 'ses-dead').deletedAt, isNull);

      final deadFamilyRecord = inspector.allRecords.firstWhere((r) => r.id == 'fam-dead');
      await inspector.restoreRecord(deadFamilyRecord);
      expect(attRepo.families.firstWhere((f) => f.id == 'fam-dead').deletedAt, isNull);

      final deadMemberRecord = inspector.allRecords.firstWhere((r) => r.id == 'm-bob-dead');
      await inspector.restoreRecord(deadMemberRecord);
      final restoredBob = attRepo.families
          .expand((f) => f.members)
          .firstWhere((m) => m.id == 'm-bob-dead');
      expect(restoredBob.deletedAt, isNull);
    });
  });

  group('Mark editing and relinking', () {
    test('relinks mark to active member', () async {
      await inspector.scan();

      final orphanRecord = inspector.allRecords.firstWhere(
        (r) => r.table == 'attendance' && r.fields['member_id'] == 'm-orphan',
      );

      final alice = inspector.families
          .expand((f) => f.members)
          .firstWhere((m) => m.id == 'm-alice');

      await inspector.relinkMark(orphanRecord, alice);

      final updatedSession = sessionRepo.sessions.firstWhere((s) => s.id == 'ses-live-1');
      expect(
        updatedSession.records.any((r) => r.memberId == 'm-alice' && r.attendee == 'Alice Smith'),
        isTrue,
      );
    });

    test('keeps mark as guest without memberId', () async {
      await inspector.scan();

      final orphanRecord = inspector.allRecords.firstWhere(
        (r) => r.table == 'attendance' && r.fields['member_id'] == 'm-orphan',
      );

      await inspector.keepMarkAsGuest(orphanRecord);

      final updatedSession = sessionRepo.sessions.firstWhere((s) => s.id == 'ses-live-1');
      final guestMark = updatedSession.records.firstWhere((r) => r.attendee == 'Orphan Dan');
      expect(guestMark.memberId, isNull);
    });

    test('updates mark attendance status', () async {
      await inspector.scan();

      final orphanRecord = inspector.allRecords.firstWhere(
        (r) => r.table == 'attendance' && r.fields['member_id'] == 'm-orphan',
      );

      await inspector.updateMarkStatus(orphanRecord, AttendanceStatus.present);

      final updatedSession = sessionRepo.sessions.firstWhere((s) => s.id == 'ses-live-1');
      final updatedMark = updatedSession.records.firstWhere((r) => r.attendee == 'Orphan Dan');
      expect(updatedMark.status, AttendanceStatus.present);
    });
  });

  group('Bulk operations delegation', () {
    test('simulates and executes merge through bulkService', () async {
      await inspector.scan();

      final dryRun = await inspector.simulateMerge(
        sourceIdentifier: 'Orphan Dan',
        sourceName: 'Orphan Dan',
        targetMemberId: 'm-alice',
        targetName: 'Alice Smith',
        updateRoster: false,
      );

      expect(dryRun.sessionsAffected, 1);
      expect(dryRun.marksUpdated, 1);

      await inspector.executeMerge(
        sourceIdentifier: 'Orphan Dan',
        sourceName: 'Orphan Dan',
        targetMemberId: 'm-alice',
        targetName: 'Alice Smith',
        updateRoster: false,
      );

      // Verify merge was applied and inspector re-scanned
      final updatedSession = sessionRepo.sessions.firstWhere((s) => s.id == 'ses-live-1');
      expect(updatedSession.records.any((r) => r.attendee == 'Orphan Dan'), isFalse);
    });

    test('simulates and executes rename through bulkService', () async {
      await inspector.scan();

      final dryRun = await inspector.simulateRename(
        oldName: 'Guest Gary',
        newName: 'Gary Guest',
        memberId: null,
        updateRoster: false,
      );

      expect(dryRun.sessionsAffected, 1);
      expect(dryRun.marksUpdated, 1);

      await inspector.executeRename(
        oldName: 'Guest Gary',
        newName: 'Gary Guest',
        memberId: null,
        updateRoster: false,
      );

      // Verify rename was applied
      final updatedSession = sessionRepo.sessions.firstWhere((s) => s.id == 'ses-live-1');
      expect(updatedSession.records.any((r) => r.attendee == 'Gary Guest'), isTrue);
    });
  });
}
