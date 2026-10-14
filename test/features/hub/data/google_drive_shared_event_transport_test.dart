import 'dart:convert';

import 'package:attendance_tracker/features/hub/data/google_drive_shared_event_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:mocktail/mocktail.dart';

class MockDriveApi extends Mock implements drive.DriveApi {}
class MockFilesResource extends Mock implements drive.FilesResource {}
class MockPermissionsResource extends Mock implements drive.PermissionsResource {}

class FakeDriveFile extends Fake implements drive.File {}
class FakePermission extends Fake implements drive.Permission {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeDriveFile());
    registerFallbackValue(FakePermission());
  });

  group('GoogleDriveSharedEventTransport', () {
    late MockDriveApi mockDriveApi;
    late MockFilesResource mockFiles;
    late MockPermissionsResource mockPermissions;
    late GoogleDriveSharedEventTransport transport;

    setUp(() {
      mockDriveApi = MockDriveApi();
      mockFiles = MockFilesResource();
      mockPermissions = MockPermissionsResource();

      when(() => mockDriveApi.files).thenReturn(mockFiles);
      when(() => mockDriveApi.permissions).thenReturn(mockPermissions);

      transport = GoogleDriveSharedEventTransport(driveApiProvider: () => mockDriveApi);
    });

    test('throws StateError if driveApi is null', () {
      final uninitTransport = GoogleDriveSharedEventTransport(driveApiProvider: () => null);

      expect(() => uninitTransport.discoverSharedFolders(), throwsStateError);
      expect(() => uninitTransport.readFile('f', 'e'), throwsStateError);
      expect(() => uninitTransport.writeFile('f', 'e', 'c'), throwsStateError);
      expect(() => uninitTransport.createSharedFolder('ev'), throwsStateError);
      expect(() => uninitTransport.inviteCollaborator('f', 'e'), throwsStateError);
      expect(() => uninitTransport.revokeCollaborator('f', 'p'), throwsStateError);
      expect(() => uninitTransport.listCollaborators('f'), throwsStateError);
      expect(() => uninitTransport.unshareFolder('f'), throwsStateError);
    });

    test('discoverSharedFolders lists folders shared with me', () async {
      when(() => mockFiles.list(
        q: any(named: 'q'),
        $fields: any(named: r'$fields'),
      )).thenAnswer((_) async => drive.FileList(files: [
        drive.File()..id = 'f-1'..name = 'Event One',
        drive.File()..id = 'f-2'..name = 'Event Two',
        drive.File()..id = null..name = 'No Id',
      ]));

      final result = await transport.discoverSharedFolders();
      expect(result.length, 2);
      expect(result[0].id, 'f-1');
      expect(result[0].name, 'Event One');
      expect(result[1].id, 'f-2');
      expect(result[1].name, 'Event Two');
    });

    test('readFile returns string when file exists', () async {
      when(() => mockFiles.list(
        q: any(named: 'q'),
        $fields: any(named: r'$fields'),
      )).thenAnswer((_) async => drive.FileList(files: [drive.File()..id = 'file-123']));

      final bytes = utf8.encode('{"hello":"world"}');
      final media = drive.Media(Stream.value(bytes), bytes.length);

      when(() => mockFiles.get(
        'file-123',
        downloadOptions: drive.DownloadOptions.fullMedia,
      )).thenAnswer((_) async => media);

      final content = await transport.readFile('folder-1', 'test.json');
      expect(content, '{"hello":"world"}');
    });

    test('readFile returns null when file does not exist', () async {
      when(() => mockFiles.list(
        q: any(named: 'q'),
        $fields: any(named: r'$fields'),
      )).thenAnswer((_) async => drive.FileList(files: []));

      final content = await transport.readFile('folder-1', 'missing.json');
      expect(content, isNull);
    });

    test('writeFile updates file when it already exists', () async {
      when(() => mockFiles.list(
        q: any(named: 'q'),
        $fields: any(named: r'$fields'),
      )).thenAnswer((_) async => drive.FileList(files: [drive.File()..id = 'existing-file-id']));

      when(() => mockFiles.update(
        any(),
        any(),
        uploadMedia: any(named: 'uploadMedia'),
      )).thenAnswer((_) async => drive.File());

      await transport.writeFile('folder-1', 'data.json', 'content');

      verify(() => mockFiles.update(
        any(),
        'existing-file-id',
        uploadMedia: any(named: 'uploadMedia'),
      )).called(1);
    });

    test('writeFile creates new file when it does not exist', () async {
      when(() => mockFiles.list(
        q: any(named: 'q'),
        $fields: any(named: r'$fields'),
      )).thenAnswer((_) async => drive.FileList(files: []));

      when(() => mockFiles.create(
        any(),
        uploadMedia: any(named: 'uploadMedia'),
      )).thenAnswer((_) async => drive.File()..id = 'new-file-id');

      await transport.writeFile('folder-1', 'data.json', 'content');

      verify(() => mockFiles.create(
        any(that: predicate<drive.File>((f) => f.name == 'data.json' && f.parents?.contains('folder-1') == true)),
        uploadMedia: any(named: 'uploadMedia'),
      )).called(1);
    });

    test('createSharedFolder creates root if needed and creates event subfolder', () async {
      when(() => mockFiles.list(
        q: any(named: 'q'),
        $fields: any(named: r'$fields'),
      )).thenAnswer((invocation) async {
        final q = invocation.namedArguments[#q] as String;
        if (q.contains("name = '${GoogleDriveSharedEventTransport.rootSharedFolderName}'")) {
          return drive.FileList(files: []);
        }
        return drive.FileList(files: []);
      });

      when(() => mockFiles.create(
        any(),
        $fields: any(named: r'$fields'),
      )).thenAnswer((invocation) async {
        final file = invocation.positionalArguments[0] as drive.File;
        if (file.name == GoogleDriveSharedEventTransport.rootSharedFolderName) {
          return drive.File()..id = 'root-id';
        }
        return drive.File()..id = 'subfolder-${file.name}';
      });

      final folderId = await transport.createSharedFolder('ev-42');
      expect(folderId, 'subfolder-ev-42');
    });

    test('createSharedFolder reuses existing root and subfolder if present', () async {
      when(() => mockFiles.list(
        q: any(named: 'q'),
        $fields: any(named: r'$fields'),
      )).thenAnswer((invocation) async {
        final q = invocation.namedArguments[#q] as String;
        if (q.contains("name = '${GoogleDriveSharedEventTransport.rootSharedFolderName}'")) {
          return drive.FileList(files: [drive.File()..id = 'existing-root-id']);
        }
        if (q.contains("name = 'ev-99'")) {
          return drive.FileList(files: [drive.File()..id = 'existing-subfolder-id']);
        }
        return drive.FileList(files: []);
      });

      final folderId = await transport.createSharedFolder('ev-99');
      expect(folderId, 'existing-subfolder-id');
      verifyNever(() => mockFiles.create(any(), $fields: any(named: r'$fields')));
    });

    test('inviteCollaborator creates permission and maps to RemotePermission', () async {
      when(() => mockPermissions.create(
        any(),
        any(),
        sendNotificationEmail: any(named: 'sendNotificationEmail'),
      )).thenAnswer((_) async => drive.Permission(
        id: 'perm-abc',
        role: 'writer',
        type: 'user',
        emailAddress: 'guest@test.com',
        displayName: 'Guest Test',
      ));

      final perm = await transport.inviteCollaborator('folder-1', 'guest@test.com');
      expect(perm.id, 'perm-abc');
      expect(perm.emailAddress, 'guest@test.com');
      expect(perm.displayName, 'Guest Test');
      expect(perm.role, 'writer');

      verify(() => mockPermissions.create(
        any(that: predicate<drive.Permission>((p) => p.emailAddress == 'guest@test.com' && p.role == 'writer')),
        'folder-1',
        sendNotificationEmail: true,
      )).called(1);
    });

    test('revokeCollaborator deletes permission on drive API', () async {
      when(() => mockPermissions.delete(any(), any())).thenAnswer((_) async => '');

      await transport.revokeCollaborator('folder-1', 'perm-1');
      verify(() => mockPermissions.delete('folder-1', 'perm-1')).called(1);
    });

    test('listCollaborators lists permissions on folder', () async {
      when(() => mockPermissions.list(
        'folder-1',
        $fields: any(named: r'$fields'),
      )).thenAnswer((_) async => drive.PermissionList(permissions: [
        drive.Permission(id: 'p1', role: 'writer', emailAddress: 'a@b.com', displayName: 'A B'),
      ]));

      final result = await transport.listCollaborators('folder-1');
      expect(result.length, 1);
      expect(result.first.id, 'p1');
      expect(result.first.emailAddress, 'a@b.com');
    });

    test('unshareFolder updates file trashed = true', () async {
      when(() => mockFiles.update(any(), any())).thenAnswer((_) async => drive.File());

      await transport.unshareFolder('folder-123');

      verify(() => mockFiles.update(
        any(that: predicate<drive.File>((f) => f.trashed == true)),
        'folder-123',
      )).called(1);
    });
  });
}
