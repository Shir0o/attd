import 'dart:convert';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_start_mode.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/marking_mode.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/models/roster_grouping.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/data/in_memory_shared_event_transport.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/hub/domain/shared_event_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockEventRepository extends Mock implements EventRepository {}
class MockAttendanceRepository extends Mock implements AttendanceRepository {}
class MockSessionRepository extends Mock implements SessionRepository {}

class FakeEvent extends Fake implements Event {}
class FakeMember extends Fake implements Member {}
class FakeSession extends Fake implements Session {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeEvent());
    registerFallbackValue(FakeMember());
    registerFallbackValue(FakeSession());
  });

  group('SharedSlice - Generation and Merge Logic', () {
    final now = DateTime.utc(2026, 9, 21, 10, 0);

    test('generate includes only assigned members and strips sensitive notes', () {
      final event = Event(
        id: 'ev-test',
        title: 'Sunday Service',
        time: const TimeOfDay(hour: 9, minute: 30),
        frequency: 'Weekly',
        repeatingDays: ['Sunday'],
        memberIds: ['m1', 'm2'],
        defaultAttendanceStartMode: AttendanceStartMode.allPresent,
        rosterGrouping: RosterGrouping.byStatus,
        markingMode: MarkingMode.likelyHere,
        createdAt: now,
      );

      final members = [
        Member(
          id: 'm1',
          displayName: 'Alice Johnson',
          canonicalName: 'Alice Johnson Confidential',
          isVisitor: false,
          updatedAt: now,
        ),
        Member(
          id: 'm2',
          displayName: 'Bob Smith',
          canonicalName: 'Bob Smith Secret',
          isVisitor: false,
          updatedAt: now,
        ),
        Member(
          id: 'm3',
          displayName: 'Charlie Unrelated',
          updatedAt: now,
        ),
      ];

      final session = Session(
        id: 'sess-1',
        eventId: 'ev-test',
        title: 'Sunday Service',
        sessionDate: now,
        createdBy: 'Alice',
        createdAt: now,
        updatedAt: now,
        records: [
          SessionRecord(
            memberId: 'm1',
            attendee: 'Alice Johnson',
            status: AttendanceStatus.present,
            recordedAt: now,
            recordedBy: 'Alice',
          ),
          SessionRecord(
            memberId: null,
            attendee: 'Guest Walk-in',
            status: AttendanceStatus.present,
            recordedAt: now,
            recordedBy: 'Alice',
          ),
        ],
      );

      final slice = SharedSlice.generate(
        event: event,
        allMembers: members,
        sessions: [session],
      );

      final eventMap = jsonDecode(slice.sharedEventJson) as Map<String, dynamic>;
      expect(eventMap['id'], 'ev-test');
      expect(eventMap['title'], 'Sunday Service');
      expect(eventMap['defaultAttendanceStartMode'], 'allPresent');
      expect(eventMap['rosterGrouping'], 'byStatus');
      expect(eventMap['markingMode'], 'likelyHere');
      expect(eventMap['memberIds'], ['m1', 'm2']);

      final rosterList = jsonDecode(slice.sharedRosterJson) as List<dynamic>;
      expect(rosterList.length, 2);
      expect(rosterList.any((m) => m['id'] == 'm1'), isTrue);
      expect(rosterList.any((m) => m['id'] == 'm2'), isTrue);
      expect(rosterList.any((m) => m['id'] == 'm3'), isFalse);

      final m1Map = rosterList.firstWhere((m) => m['id'] == 'm1') as Map<String, dynamic>;
      expect(m1Map['displayName'], 'Alice Johnson');
      expect(m1Map.containsKey('canonicalName'), isFalse);

      final sessionsList = jsonDecode(slice.sharedSessionsJson) as List<dynamic>;
      expect(sessionsList.length, 1);
      final sMap = sessionsList.first as Map<String, dynamic>;
      expect(sMap['records'].length, 2);
    });

    test('mergeRecords applies presence precedence over absent', () {
      final earlierPresent = SessionRecord(
        memberId: 'm1',
        attendee: 'Alice',
        status: AttendanceStatus.present,
        recordedAt: now,
        recordedBy: 'Alice',
      );
      final laterAbsent = SessionRecord(
        memberId: 'm1',
        attendee: 'Alice',
        status: AttendanceStatus.absent,
        recordedAt: now.add(const Duration(hours: 1)),
        recordedBy: 'Bob',
      );

      // Present beats Absent even if Absent was recorded later
      final merged1 = SharedSlice.mergeRecords(earlierPresent, laterAbsent);
      expect(merged1.status, AttendanceStatus.present);
      expect(merged1.recordedBy, 'Alice');

      final merged2 = SharedSlice.mergeRecords(laterAbsent, earlierPresent);
      expect(merged2.status, AttendanceStatus.present);
      expect(merged2.recordedBy, 'Alice');
    });

    test('mergeRecords resolves same-status conflicts by latest timestamp', () {
      final earlierPresent = SessionRecord(
        memberId: 'm1',
        attendee: 'Alice',
        status: AttendanceStatus.present,
        isLate: false,
        recordedAt: now,
        recordedBy: 'Alice',
      );
      final laterLate = SessionRecord(
        memberId: 'm1',
        attendee: 'Alice',
        status: AttendanceStatus.present,
        isLate: true,
        recordedAt: now.add(const Duration(minutes: 15)),
        recordedBy: 'Door Scanner',
      );

      final merged = SharedSlice.mergeRecords(earlierPresent, laterLate);
      expect(merged.isLate, isTrue);
      expect(merged.recordedBy, 'Door Scanner');

      final earlierAbsent = SessionRecord(
        memberId: 'm2',
        attendee: 'Bob',
        status: AttendanceStatus.absent,
        recordedAt: now,
        recordedBy: 'Reviewer A',
      );
      final laterAbsent = SessionRecord(
        memberId: 'm2',
        attendee: 'Bob',
        status: AttendanceStatus.absent,
        recordedAt: now.add(const Duration(minutes: 5)),
        recordedBy: 'Reviewer B',
      );

      final mergedAbsent = SharedSlice.mergeRecords(earlierAbsent, laterAbsent);
      expect(mergedAbsent.recordedBy, 'Reviewer B');
    });

    test('mergeSessionLists merges sessions and preserves guest marks', () {
      final localSession = Session(
        id: 's-1',
        title: 'Youth Group',
        sessionDate: now,
        createdBy: 'Alice',
        createdAt: now,
        updatedAt: now,
        records: [
          SessionRecord(
            memberId: 'm1',
            attendee: 'Member One',
            status: AttendanceStatus.present,
            recordedAt: now,
            recordedBy: 'Alice',
          ),
        ],
      );

      final remoteSession = Session(
        id: 's-1',
        title: 'Youth Group',
        sessionDate: now,
        createdBy: 'Alice',
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 10)),
        records: [
          SessionRecord(
            memberId: null,
            attendee: 'Guest Walk-in',
            status: AttendanceStatus.present,
            recordedAt: now.add(const Duration(minutes: 2)),
            recordedBy: 'Door Volunteer',
          ),
        ],
      );

      final merged = SharedSlice.mergeSessionLists([localSession], [remoteSession]);
      expect(merged.length, 1);
      final records = merged.first.records;
      expect(records.length, 2);

      final guestRecord = records.firstWhere((r) => r.memberId == null);
      expect(guestRecord.attendee, 'Guest Walk-in');
      expect(guestRecord.recordedBy, 'Door Volunteer');
      expect(merged.first.currentVersion, 2);
    });
  });

  group('SharedEventSyncCoordinator - In-Memory Transport', () {
    late InMemorySharedEventTransport transport;
    late MockEventRepository mockEventRepo;
    late MockAttendanceRepository mockAttendanceRepo;
    late MockSessionRepository mockSessionRepo;
    late SharedEventSync syncCoordinator;

    final now = DateTime.utc(2026, 9, 21, 10, 0);

    setUp(() {
      transport = InMemorySharedEventTransport();
      mockEventRepo = MockEventRepository();
      mockAttendanceRepo = MockAttendanceRepository();
      mockSessionRepo = MockSessionRepository();

      syncCoordinator = SharedEventSync(
        transport: transport,
        eventRepository: mockEventRepo,
        attendanceRepository: mockAttendanceRepo,
        sessionRepository: mockSessionRepo,
      );
    });

    test('syncSharedEvents discovers remote slices, creates synthetic family and merges sessions', () async {
      // Seed transport with a remote shared event
      final eventContent = jsonEncode({
        'id': 'ev-remote-1',
        'title': 'Fellowship Camp',
        'time': '14:00',
        'frequency': 'One-time',
        'createdAt': '2026-09-21T10:00:00.000Z',
      });
      final rosterContent = jsonEncode([
        {'id': 'mem-1', 'displayName': 'Camper Joe'},
        {'id': 'mem-2', 'displayName': 'Camper Sally'},
      ]);
      final sessionsContent = jsonEncode([
        {
          'id': 'sess-remote-1',
          'title': 'Fellowship Camp',
          'eventId': 'ev-remote-1',
          'sessionDate': '2026-09-21T00:00:00.000Z',
          'createdAt': '2026-09-21T00:00:00.000Z',
          'updatedAt': '2026-09-21T00:00:00.000Z',
          'createdBy': 'Remote Organizer',
          'records': [
            {
              'memberId': 'mem-1',
              'attendee': 'Camper Joe',
              'status': 'present',
              'recordedAt': '2026-09-21T09:00:00.000Z',
              'recordedBy': 'Door',
            }
          ],
        }
      ]);

      transport.seedFolder(
        folderId: 'folder-camp',
        name: 'ev-remote-1',
        isSharedWithMe: true,
        files: {
          SharedSlice.sharedEventFileName: eventContent,
          SharedSlice.sharedRosterFileName: rosterContent,
          SharedSlice.sharedSessionsFileName: sessionsContent,
        },
      );

      // Repo mocks
      when(() => mockEventRepo.findEventById('ev-remote-1')).thenAnswer((_) async => null);
      when(() => mockEventRepo.createEvent(any())).thenAnswer((_) async {});
      when(() => mockAttendanceRepo.fetchFamilies()).thenAnswer((_) async => []);
      when(() => mockAttendanceRepo.addFamily('Fellowship Camp Roster')).thenAnswer(
        (_) async => Family(id: 'fam-camp', displayName: 'Fellowship Camp Roster', members: []),
      );
      when(() => mockAttendanceRepo.addMember(any(), any())).thenAnswer(
        (inv) async => Family(
          id: 'fam-camp',
          displayName: 'Fellowship Camp Roster',
          members: [inv.positionalArguments[1] as Member],
        ),
      );
      when(() => mockSessionRepo.loadSessions()).thenAnswer((_) async => []);
      when(() => mockSessionRepo.findSessionById('sess-remote-1')).thenAnswer((_) async => null);
      when(() => mockSessionRepo.createSession(
        title: any(named: 'title'),
        eventId: any(named: 'eventId'),
        sessionDate: any(named: 'sessionDate'),
        actor: any(named: 'actor'),
        records: any(named: 'records'),
      )).thenAnswer((_) async => Session(
        id: 'sess-remote-1',
        title: 'Fellowship Camp',
        sessionDate: now,
        records: const [],
        createdAt: now,
        updatedAt: now,
        createdBy: 'Remote Organizer',
      ));

      await syncCoordinator.syncSharedEvents();

      // Verify event created as read-only shared event
      verify(() => mockEventRepo.createEvent(
        any(that: predicate<Event>((e) =>
          e.id == 'ev-remote-1' &&
          e.title == 'Fellowship Camp' &&
          e.isShared == true &&
          e.isReadOnly == true &&
          e.sharedFolderId == 'folder-camp'
        )),
      )).called(1);

      // Verify synthetic family created
      verify(() => mockAttendanceRepo.addFamily('Fellowship Camp Roster')).called(1);

      // Verify members added to synthetic family
      verify(() => mockAttendanceRepo.addMember('fam-camp', any(that: predicate<Member>((m) => m.id == 'mem-1')))).called(1);
      verify(() => mockAttendanceRepo.addMember('fam-camp', any(that: predicate<Member>((m) => m.id == 'mem-2')))).called(1);

      // Verify session created
      verify(() => mockSessionRepo.createSession(
        title: 'Fellowship Camp',
        eventId: 'ev-remote-1',
        sessionDate: any(named: 'sessionDate'),
        actor: 'Remote Organizer',
        records: any(named: 'records'),
      )).called(1);
    });

    test('syncSharedEvents updates existing event and snapshots existing session', () async {
      final eventContent = jsonEncode({
        'id': 'ev-existing-1',
        'title': 'Existing Event',
        'time': '10:00',
        'frequency': 'Weekly',
        'createdAt': now.toIso8601String(),
      });
      final rosterContent = jsonEncode([]);
      final sessionsContent = jsonEncode([
        {
          'id': 'sess-existing-1',
          'title': 'Existing Event',
          'eventId': 'ev-existing-1',
          'sessionDate': now.toIso8601String(),
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'createdBy': 'Author',
          'records': [],
        }
      ]);

      transport.seedFolder(
        folderId: 'folder-existing',
        name: 'ev-existing-1',
        files: {
          SharedSlice.sharedEventFileName: eventContent,
          SharedSlice.sharedRosterFileName: rosterContent,
          SharedSlice.sharedSessionsFileName: sessionsContent,
        },
      );

      final existingEvent = Event(
        id: 'ev-existing-1',
        title: 'Old Title',
        time: const TimeOfDay(hour: 9, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
      );

      final existingSession = Session(
        id: 'sess-existing-1',
        title: 'Existing Event',
        sessionDate: now,
        records: const [],
        createdAt: now,
        updatedAt: now,
        createdBy: 'Author',
      );

      when(() => mockEventRepo.findEventById('ev-existing-1')).thenAnswer((_) async => existingEvent);
      when(() => mockEventRepo.updateEvent(any())).thenAnswer((_) async {});
      when(() => mockAttendanceRepo.fetchFamilies()).thenAnswer((_) async => [
        Family(id: 'fam-1', displayName: 'Existing Event Roster', members: []),
      ]);
      when(() => mockSessionRepo.loadSessions()).thenAnswer((_) async => [existingSession]);
      when(() => mockSessionRepo.findSessionById('sess-existing-1')).thenAnswer((_) async => existingSession);
      when(() => mockSessionRepo.saveSnapshot(any(), actor: 'Sync')).thenAnswer((_) async => existingSession);

      await syncCoordinator.syncSharedEvents();

      verify(() => mockEventRepo.updateEvent(any(that: predicate<Event>((e) => e.id == 'ev-existing-1')))).called(1);
      verify(() => mockSessionRepo.saveSnapshot(any(), actor: 'Sync')).called(1);
    });

    test('syncSharedEvents skips folders with missing slice files', () async {
      transport.seedFolder(
        folderId: 'folder-corrupt',
        name: 'ev-corrupt',
        files: {
          // Missing shared_roster.json
          SharedSlice.sharedEventFileName: '{"id":"ev-corrupt","title":"Corrupt"}',
        },
      );

      await syncCoordinator.syncSharedEvents();

      verifyNever(() => mockEventRepo.createEvent(any()));
      verifyNever(() => mockEventRepo.updateEvent(any()));
    });

    test('syncSharedEvent performs bi-directional sync and uploads updated slice', () async {
      final remoteSessionJson = jsonEncode([
        {
          'id': 'sess-1',
          'title': 'Youth Group',
          'eventId': 'ev-sync-1',
          'sessionDate': now.toIso8601String(),
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'createdBy': 'Remote',
          'records': [
            {
              'memberId': 'm1',
              'attendee': 'Alice',
              'status': 'present',
              'recordedAt': now.toIso8601String(),
              'recordedBy': 'Remote Door',
            }
          ],
        }
      ]);

      transport.seedFolder(
        folderId: 'folder-sync-1',
        name: 'ev-sync-1',
        files: {
          SharedSlice.sharedEventFileName: '{"id":"ev-sync-1","title":"Youth Group"}',
          SharedSlice.sharedRosterFileName: '[]',
          SharedSlice.sharedSessionsFileName: remoteSessionJson,
        },
      );

      final event = Event(
        id: 'ev-sync-1',
        title: 'Youth Group',
        time: const TimeOfDay(hour: 10, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
        isShared: true,
        sharedFolderId: 'folder-sync-1',
      );

      when(() => mockSessionRepo.loadSessions()).thenAnswer((_) async => []);
      when(() => mockSessionRepo.findSessionById('sess-1')).thenAnswer((_) async => null);
      when(() => mockSessionRepo.createSession(
        title: any(named: 'title'),
        eventId: any(named: 'eventId'),
        sessionDate: any(named: 'sessionDate'),
        actor: any(named: 'actor'),
        records: any(named: 'records'),
      )).thenAnswer((_) async => Session(
        id: 'sess-1',
        title: 'Youth Group',
        sessionDate: now,
        records: const [],
        createdAt: now,
        updatedAt: now,
        createdBy: 'Remote',
      ));
      when(() => mockAttendanceRepo.fetchFamilies()).thenAnswer((_) async => []);

      await syncCoordinator.syncSharedEvent(event);

      verify(() => mockSessionRepo.createSession(
        title: 'Youth Group',
        eventId: 'ev-sync-1',
        sessionDate: any(named: 'sessionDate'),
        actor: any(named: 'actor'),
        records: any(named: 'records'),
      )).called(1);

      // Verify that the updated slice was uploaded to the transport
      final files = transport.getFolderFiles('folder-sync-1');
      expect(files, isNotNull);
      expect(files![SharedSlice.sharedSessionsFileName], isNotNull);
    });

    test('syncSharedEvent does nothing when sharedFolderId is null', () async {
      final unsharedEvent = Event(
        id: 'ev-unshared',
        title: 'Local Only',
        time: const TimeOfDay(hour: 10, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
      );

      await syncCoordinator.syncSharedEvent(unsharedEvent);
      verifyNever(() => mockSessionRepo.loadSessions());
    });

    test('publishSharedEvent creates folder, uploads slice, and updates event', () async {
      final event = Event(
        id: 'ev-publish',
        title: 'Publish Test',
        time: const TimeOfDay(hour: 18, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
      );

      when(() => mockAttendanceRepo.fetchFamilies()).thenAnswer((_) async => []);
      when(() => mockSessionRepo.loadSessions()).thenAnswer((_) async => []);
      when(() => mockEventRepo.updateEvent(any())).thenAnswer((_) async {});

      final folderId = await syncCoordinator.publishSharedEvent(event);
      expect(folderId, 'folder-ev-publish');

      final files = transport.getFolderFiles(folderId);
      expect(files, isNotNull);
      expect(files![SharedSlice.sharedEventFileName], contains('ev-publish'));
      expect(files[SharedSlice.sharedRosterFileName], equals('[]'));
      expect(files[SharedSlice.sharedSessionsFileName], equals('[]'));

      verify(() => mockEventRepo.updateEvent(any(that: predicate<Event>((e) =>
        e.id == 'ev-publish' && e.isShared == true && e.sharedFolderId == folderId
      )))).called(1);
    });

    test('unshareEvent trashes folder and updates event', () async {
      final event = Event(
        id: 'ev-unshare',
        title: 'Unshare Test',
        time: const TimeOfDay(hour: 18, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
        isShared: true,
        sharedFolderId: 'folder-ev-unshare',
        collaborators: ['collab@gmail.com'],
      );

      transport.seedFolder(folderId: 'folder-ev-unshare', name: 'ev-unshare');
      when(() => mockEventRepo.updateEvent(any())).thenAnswer((_) async {});

      await syncCoordinator.unshareEvent(event);

      expect(transport.isFolderTrashed('folder-ev-unshare'), isTrue);
      verify(() => mockEventRepo.updateEvent(any(that: predicate<Event>((e) =>
        e.id == 'ev-unshare' && e.isShared == false && e.collaborators.isEmpty
      )))).called(1);
    });

    test('collaborator operations delegate to transport', () async {
      final perm = await syncCoordinator.inviteCollaborator('folder-1', 'collab@example.com');
      expect(perm.emailAddress, 'collab@example.com');
      expect(perm.role, 'writer');

      final list = await syncCoordinator.listCollaborators('folder-1');
      expect(list.length, 1);
      expect(list.first.id, perm.id);

      await syncCoordinator.revokeCollaborator('folder-1', perm.id);
      final emptyList = await syncCoordinator.listCollaborators('folder-1');
      expect(emptyList.isEmpty, isTrue);
    });
  });
}
