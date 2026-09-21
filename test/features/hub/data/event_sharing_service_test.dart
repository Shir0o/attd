import 'dart:convert';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/data/event_sharing_service.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:mocktail/mocktail.dart';

class MockDriveApi extends Mock implements drive.DriveApi {}
class MockFilesResource extends Mock implements drive.FilesResource {}
class MockPermissionsResource extends Mock implements drive.PermissionsResource {}
class MockEventRepository extends Mock implements EventRepository {}
class MockAttendanceRepository extends Mock implements AttendanceRepository {}
class MockSessionRepository extends Mock implements SessionRepository {}

class FakeDriveFile extends Fake implements drive.File {}
class FakePermission extends Fake implements drive.Permission {}
class FakeEvent extends Fake implements Event {}
class FakeMember extends Fake implements Member {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeDriveFile());
    registerFallbackValue(FakePermission());
    registerFallbackValue(FakeEvent());
    registerFallbackValue(FakeMember());
  });

  group('EventSharingService - Shared Slice Generation', () {
    test('generateSharedSlice includes only assigned members and strips sensitive data', () {
      final now = DateTime.utc(2026, 9, 21, 12, 0);
      final event = Event(
        id: 'ev-1',
        title: 'Youth Group',
        time: const TimeOfDay(hour: 18, minute: 30),
        frequency: 'Weekly',
        repeatingDays: ['Friday'],
        memberIds: ['m1', 'm2'],
        createdAt: now,
      );

      final members = [
        Member(
          id: 'm1',
          displayName: 'John Doe',
          canonicalName: 'John Doe Private',
          isVisitor: false,
          updatedAt: now,
        ),
        Member(
          id: 'm2',
          displayName: 'Jane Smith',
          canonicalName: 'Jane Smith Confidential',
          isVisitor: false,
          updatedAt: now,
        ),
        Member(
          id: 'm3',
          displayName: 'Unrelated Member',
          updatedAt: now,
        ),
      ];

      final session = Session(
        id: 's-1',
        eventId: 'ev-1',
        title: 'Youth Group',
        sessionDate: now,
        createdBy: 'Alice',
        createdAt: now,
        updatedAt: now,
        records: [
          SessionRecord(
            memberId: 'm1',
            attendee: 'John Doe',
            status: AttendanceStatus.present,
            recordedAt: now,
            recordedBy: 'Alice',
          ),
          SessionRecord(
            memberId: null,
            attendee: 'Guest Guy',
            status: AttendanceStatus.present,
            recordedAt: now,
            recordedBy: 'Alice',
          ),
        ],
      );

      final slice = EventSharingService.generateSharedSlice(
        event: event,
        allMembers: members,
        sessions: [session],
      );

      // 1. shared_event.json contains event definition
      final sharedEventJson = jsonDecode(slice.sharedEventJson) as Map<String, dynamic>;
      expect(sharedEventJson['id'], 'ev-1');
      expect(sharedEventJson['title'], 'Youth Group');
      expect(sharedEventJson['memberIds'], ['m1', 'm2']);

      // 2. shared_roster.json contains ONLY assigned members with minimal fields
      final sharedRosterJson = jsonDecode(slice.sharedRosterJson) as List<dynamic>;
      expect(sharedRosterJson.length, 2);
      final m1Json = sharedRosterJson.firstWhere((m) => m['id'] == 'm1') as Map<String, dynamic>;
      expect(m1Json['id'], 'm1');
      expect(m1Json['displayName'], 'John Doe');
      // Should not contain canonical name or notes
      expect(m1Json.containsKey('canonicalName'), isFalse);
      expect(sharedRosterJson.any((m) => m['id'] == 'm3'), isFalse);

      // 3. shared_sessions.json contains event sessions with guest marks
      final sharedSessionsJson = jsonDecode(slice.sharedSessionsJson) as List<dynamic>;
      expect(sharedSessionsJson.length, 1);
      final sJson = sharedSessionsJson.first as Map<String, dynamic>;
      expect(sJson['id'], 's-1');
      expect(sJson['records'].length, 2);
    });
  });

  group('EventSharingService - Presence Precedence Merge', () {
    final now = DateTime.utc(2026, 9, 21, 10, 0);

    test('Present or Late overrides Absent regardless of timestamp', () {
      final earlierPresent = SessionRecord(
        memberId: 'm1',
        attendee: 'John Doe',
        status: AttendanceStatus.present,
        recordedAt: now,
        recordedBy: 'Door Scanner (Alice)',
      );

      final laterAbsent = SessionRecord(
        memberId: 'm1',
        attendee: 'John Doe',
        status: AttendanceStatus.absent,
        recordedAt: now.add(const Duration(minutes: 30)),
        recordedBy: 'Roster Review (Bob)',
      );

      final merged1 = EventSharingService.mergeRecords(earlierPresent, laterAbsent);
      expect(merged1.status, AttendanceStatus.present);
      expect(merged1.recordedBy, 'Door Scanner (Alice)');

      final earlierLate = SessionRecord(
        memberId: 'm2',
        attendee: 'Jane Doe',
        status: AttendanceStatus.present,
        isLate: true,
        recordedAt: now,
        recordedBy: 'Door Scanner (Alice)',
      );

      final laterAbsent2 = SessionRecord(
        memberId: 'm2',
        attendee: 'Jane Doe',
        status: AttendanceStatus.absent,
        recordedAt: now.add(const Duration(minutes: 30)),
        recordedBy: 'Roster Review (Bob)',
      );

      final merged2 = EventSharingService.mergeRecords(earlierLate, laterAbsent2);
      expect(merged2.status, AttendanceStatus.present);
      expect(merged2.isLate, isTrue);
      expect(merged2.recordedBy, 'Door Scanner (Alice)');
    });

    test('Conflict between Present and Late resolves with latest timestamp', () {
      final earlierPresent = SessionRecord(
        memberId: 'm1',
        attendee: 'John Doe',
        status: AttendanceStatus.present,
        isLate: false,
        recordedAt: now,
        recordedBy: 'Alice',
      );

      final laterLate = SessionRecord(
        memberId: 'm1',
        attendee: 'John Doe',
        status: AttendanceStatus.present,
        isLate: true,
        recordedAt: now.add(const Duration(minutes: 10)),
        recordedBy: 'Bob',
      );

      final merged = EventSharingService.mergeRecords(earlierPresent, laterLate);
      expect(merged.isLate, isTrue);
      expect(merged.recordedBy, 'Bob');

      final reversed = EventSharingService.mergeRecords(laterLate, earlierPresent);
      expect(reversed.isLate, isTrue);
      expect(reversed.recordedBy, 'Bob');
    });

    test('Guest marks with null memberId are merged and preserved', () {
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
            attendee: 'John Doe',
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
        updatedAt: now.add(const Duration(minutes: 5)),
        records: [
          SessionRecord(
            memberId: null,
            attendee: 'Walk-in Guest',
            status: AttendanceStatus.present,
            recordedAt: now.add(const Duration(minutes: 2)),
            recordedBy: 'Door Collaborator (Charlie)',
          ),
        ],
      );

      final mergedSessions = EventSharingService.mergeSessionLists([localSession], [remoteSession]);
      expect(mergedSessions.length, 1);
      final records = mergedSessions.first.records;
      expect(records.length, 2);

      final guestMark = records.firstWhere((r) => r.memberId == null);
      expect(guestMark.attendee, 'Walk-in Guest');
      expect(guestMark.status, AttendanceStatus.present);
      expect(guestMark.recordedBy, 'Door Collaborator (Charlie)');
    });
  });

  group('EventSharingService - Google Drive Operations', () {
    late MockDriveApi mockDriveApi;
    late MockFilesResource mockFiles;
    late MockPermissionsResource mockPermissions;
    late EventSharingService service;

    setUp(() {
      mockDriveApi = MockDriveApi();
      mockFiles = MockFilesResource();
      mockPermissions = MockPermissionsResource();

      when(() => mockDriveApi.files).thenReturn(mockFiles);
      when(() => mockDriveApi.permissions).thenReturn(mockPermissions);

      service = EventSharingService(driveApiProvider: () => mockDriveApi);
    });

    test('createSharedEventFolder creates subfolder under Attendance Tracker - Shared Events', () async {
      // 1. Root shared folder search & creation
      when(() => mockFiles.list(
        q: any(named: 'q'),
        $fields: any(named: r'$fields'),
      )).thenAnswer((invocation) async {
        final q = invocation.namedArguments[#q] as String;
        if (q.contains("name = 'Attendance Tracker - Shared Events'")) {
          return drive.FileList(files: [drive.File()..id = 'root-shared-folder-id']);
        }
        return drive.FileList(files: []);
      });

      // 2. Folder creation for event
      when(() => mockFiles.create(
        any(),
        $fields: any(named: r'$fields'),
      )).thenAnswer((invocation) async {
        final file = invocation.positionalArguments[0] as drive.File;
        return drive.File()
          ..id = 'event-folder-${file.name}'
          ..name = file.name;
      });

      final now = DateTime.utc(2026, 9, 21);
      final event = Event(
        id: 'ev-100',
        title: 'Youth Group',
        time: const TimeOfDay(hour: 10, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
      );

      final folderId = await service.createSharedEventFolder(event);
      expect(folderId, 'event-folder-ev-100');

      verify(() => mockFiles.create(
        any(that: predicate<drive.File>((f) =>
          f.name == 'ev-100' && f.parents?.contains('root-shared-folder-id') == true
        )),
        $fields: any(named: r'$fields'),
      )).called(1);
    });

    test('inviteCollaborator creates writer permission for email', () async {
      when(() => mockPermissions.create(
        any(),
        any(),
        sendNotificationEmail: any(named: 'sendNotificationEmail'),
      )).thenAnswer((_) async => drive.Permission(id: 'perm-1', role: 'writer', emailAddress: 'helper@gmail.com'));

      final perm = await service.inviteCollaborator('folder-1', 'helper@gmail.com');
      expect(perm.id, 'perm-1');

      verify(() => mockPermissions.create(
        any(that: predicate<drive.Permission>((p) =>
          p.role == 'writer' && p.type == 'user' && p.emailAddress == 'helper@gmail.com'
        )),
        'folder-1',
        sendNotificationEmail: any(named: 'sendNotificationEmail'),
      )).called(1);
    });

    test('revokeCollaborator deletes specific permission ID', () async {
      when(() => mockPermissions.delete(any(), any())).thenAnswer((_) async => '');

      await service.revokeCollaborator('folder-1', 'perm-1');

      verify(() => mockPermissions.delete('folder-1', 'perm-1')).called(1);
    });

    test('discoverAndIngestSharedEvents downloads slices and marks events as read-only', () async {
      final mockEventRepo = MockEventRepository();
      final mockAttendanceRepo = MockAttendanceRepository();
      final mockSessionRepo = MockSessionRepository();

      when(() => mockFiles.list(
        q: any(named: 'q'),
        $fields: any(named: r'$fields'),
      )).thenAnswer((invocation) async {
        final q = invocation.namedArguments[#q] as String;
        if (q.contains('sharedWithMe = true')) {
          return drive.FileList(files: [
            drive.File()..id = 'shared-f-1'..name = 'ev-shared',
          ]);
        }
        if (q.contains("name = 'shared_event.json'")) {
          return drive.FileList(files: [drive.File()..id = 'fe-1']);
        }
        if (q.contains("name = 'shared_roster.json'")) {
          return drive.FileList(files: [drive.File()..id = 'fr-1']);
        }
        if (q.contains("name = 'shared_sessions.json'")) {
          return drive.FileList(files: [drive.File()..id = 'fs-1']);
        }
        return drive.FileList(files: []);
      });

      final eventContent = jsonEncode({
        'id': 'ev-shared',
        'title': 'Shared Camp',
        'time': '10:0',
        'frequency': 'One-time',
        'createdAt': '2026-09-21T10:00:00.000Z',
      });
      final rosterContent = jsonEncode([
        {'id': 'm1', 'displayName': 'Camper Bob'}
      ]);
      final sessionsContent = jsonEncode([]);

      drive.Media mediaOf(String text) {
        final bytes = utf8.encode(text);
        return drive.Media(Stream.value(bytes), bytes.length);
      }

      when(() => mockFiles.get(
        'fe-1',
        downloadOptions: drive.DownloadOptions.fullMedia,
      )).thenAnswer((_) async => mediaOf(eventContent));

      when(() => mockFiles.get(
        'fr-1',
        downloadOptions: drive.DownloadOptions.fullMedia,
      )).thenAnswer((_) async => mediaOf(rosterContent));

      when(() => mockFiles.get(
        'fs-1',
        downloadOptions: drive.DownloadOptions.fullMedia,
      )).thenAnswer((_) async => mediaOf(sessionsContent));

      when(() => mockEventRepo.findEventById('ev-shared')).thenAnswer((_) async => null);
      when(() => mockEventRepo.createEvent(any())).thenAnswer((_) async {});
      when(() => mockAttendanceRepo.fetchFamilies()).thenAnswer((_) async => []);
      when(() => mockAttendanceRepo.addFamily(any())).thenAnswer((inv) async =>
        Family(id: 'fam-new', displayName: inv.positionalArguments[0] as String, members: [])
      );
      when(() => mockAttendanceRepo.addMember(any(), any())).thenAnswer((inv) async =>
        Family(id: 'fam-new', displayName: 'Shared Camp Roster', members: [inv.positionalArguments[1] as Member])
      );
      when(() => mockSessionRepo.loadSessions()).thenAnswer((_) async => []);

      await service.discoverAndIngestSharedEvents(
        eventRepo: mockEventRepo,
        attendanceRepo: mockAttendanceRepo,
        sessionRepo: mockSessionRepo,
      );

      verify(() => mockEventRepo.createEvent(
        any(that: predicate<Event>((e) =>
          e.id == 'ev-shared' && e.isShared == true && e.isReadOnly == true && e.sharedFolderId == 'shared-f-1'
        ))
      )).called(1);
    });
  });
}
