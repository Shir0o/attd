import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:archive/archive.dart';
import 'package:attendance_tracker/features/settings/data/drive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockDriveApi extends Mock implements drive.DriveApi {}

class MockFilesResource extends Mock implements drive.FilesResource {}

class _FakeDriveFile extends Fake implements drive.File {}

class _FakeDownloadOptions extends Fake implements drive.DownloadOptions {}

class _FakeMedia extends Fake implements drive.Media {}

drive.File _file(String id, String name, {DateTime? modifiedTime}) {
  return drive.File()
    ..id = id
    ..name = name
    ..modifiedTime = modifiedTime;
}

drive.Media _media(String content) {
  final bytes = utf8.encode(content);
  return drive.Media(Stream.value(bytes), bytes.length);
}

List<int> _zipOf(String filename, String content) {
  final archive = Archive()
    ..addFile(ArchiveFile(filename, content.length, utf8.encode(content)));
  return ZipEncoder().encode(archive)!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_FakeDriveFile());
    registerFallbackValue(_FakeDownloadOptions());
    registerFallbackValue(_FakeMedia());
  });

  group('DriveService with mocked DriveApi', () {
    late Directory tempDir;
    late MockGoogleSignIn signIn;
    late MockDriveApi api;
    late MockFilesResource files;
    late DriveService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('drive_service_test');
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
      SharedPreferences.setMockInitialValues({});

      signIn = MockGoogleSignIn();
      when(() => signIn.authenticationEvents).thenAnswer(
          (_) => const Stream<GoogleSignInAuthenticationEvent>.empty());

      api = MockDriveApi();
      files = MockFilesResource();
      when(() => api.files).thenReturn(files);

      service = DriveService(googleSignIn: signIn);
      service.debugSetDriveApi(api);
    });

    tearDown(() async {
      service.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    void stubBasicFolders({
      String app = 'app',
      String backup = 'backup',
      List<drive.File> childFiles = const [],
    }) {
      when(() => files.list(
            q: any(named: 'q'),
            $fields: any(named: r'$fields'),
            orderBy: any(named: 'orderBy'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((invocation) async {
        final q = invocation.namedArguments[#q] as String? ?? '';
        if (q.contains("name = 'Attendance Tracker Data'")) {
          return drive.FileList(files: [_file(app, 'Attendance Tracker Data')]);
        }
        if (q.contains("name = 'Backups'")) {
          return drive.FileList(files: [_file(backup, 'Backups')]);
        }
        if (q.contains("'$app' in parents")) {
          return drive.FileList(files: childFiles);
        }
        return drive.FileList(files: []);
      });
    }

    test('listCloudBackups returns files from backup folder', () async {
      final backups = [
        _file('b1', 'attendance_snapshot_20250101_000000.zip'),
        _file('b2', 'attendance_snapshot_20250102_000000.zip'),
      ];
      when(() => files.list(
            q: any(named: 'q'),
            $fields: any(named: r'$fields'),
            orderBy: any(named: 'orderBy'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((invocation) async {
        final q = invocation.namedArguments[#q] as String? ?? '';
        if (q.contains("name = 'Attendance Tracker Data'")) {
          return drive.FileList(files: [_file('app', 'Attendance Tracker Data')]);
        }
        if (q.contains("name = 'Backups'")) {
          return drive.FileList(files: [_file('backup', 'Backups')]);
        }
        if (q.contains('attendance_snapshot_')) {
          return drive.FileList(files: backups);
        }
        return drive.FileList(files: []);
      });

      final result = await service.listCloudBackups();

      expect(result.map((f) => f.id), ['b1', 'b2']);
    });

    test('listCloudBackups creates folders when missing', () async {
      when(() => files.list(
            q: any(named: 'q'),
            $fields: any(named: r'$fields'),
            orderBy: any(named: 'orderBy'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((_) async => drive.FileList(files: []));
      var creates = 0;
      when(() => files.create(any())).thenAnswer((_) async {
        creates++;
        return _file('created-$creates', 'created');
      });

      final result = await service.listCloudBackups();

      expect(result, isEmpty);
      // App folder + backup folder.
      expect(creates, 2);
    });

    test('syncFiles uploads local-only files and saves last sync time',
        () async {
      await File(p.join(tempDir.path, 'sessions.json')).writeAsString('[]');
      stubBasicFolders();
      var creates = 0;
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async {
        creates++;
        return _file('uploaded-$creates', 'uploaded');
      });

      await service.syncFiles();

      // sessions.json upload + backup ZIP create.
      expect(creates, greaterThanOrEqualTo(2));
      expect(service.lastSyncTime, isNotNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('drive_last_sync_time'), isNotNull);
    });

    test('syncFiles downloads remote-only files', () async {
      const remoteContent = '[{"id":"a"}]';
      stubBasicFolders(childFiles: [
        _file('remote-sessions', 'sessions.json',
            modifiedTime: DateTime.utc(2025, 1, 1)),
      ]);
      when(() => files.get(any(),
              downloadOptions: any(named: 'downloadOptions')))
          .thenAnswer((_) async => _media(remoteContent));
      when(() => files.get(any(), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => _file('remote-sessions', 'sessions.json',
              modifiedTime: DateTime.utc(2025, 1, 1)));
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('zip', 'zip'));

      await service.syncFiles();

      final downloaded = File(p.join(tempDir.path, 'sessions.json'));
      expect(downloaded.existsSync(), isTrue);
      expect(await downloaded.readAsString(), remoteContent);
    });

    test('syncFiles merges when both local and remote exist', () async {
      final local = [
        {'id': 'a', 'name': 'local', 'updatedAt': '2025-01-01T00:00:00Z'},
      ];
      final remote = [
        {'id': 'b', 'name': 'remote', 'updatedAt': '2025-01-02T00:00:00Z'},
      ];
      final localFile = File(p.join(tempDir.path, 'sessions.json'));
      await localFile.writeAsString(jsonEncode(local));

      stubBasicFolders(childFiles: [
        _file('remote-sessions', 'sessions.json',
            modifiedTime: DateTime.utc(2025, 1, 2)),
      ]);
      when(() => files.get('remote-sessions',
              downloadOptions: any(named: 'downloadOptions')))
          .thenAnswer((_) async => _media(jsonEncode(remote)));
      when(() => files.get(any(), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => _file('remote-sessions', 'sessions.json',
              modifiedTime: DateTime.utc(2025, 1, 2)));
      when(() => files.update(any(), any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('remote-sessions', 'sessions.json'));
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('zip', 'zip'));

      await service.syncFiles();

      final mergedRaw = await localFile.readAsString();
      final merged = jsonDecode(mergedRaw) as List;
      final ids = merged.map((m) => (m as Map)['id']).toSet();
      expect(ids, {'a', 'b'});
    });

    test('syncFiles rethrows friendly error when Drive API is disabled',
        () async {
      when(() => files.list(
            q: any(named: 'q'),
            $fields: any(named: r'$fields'),
            orderBy: any(named: 'orderBy'),
            pageSize: any(named: 'pageSize'),
          )).thenThrow(drive.DetailedApiRequestError(
              403, 'Google Drive API has not been used in project...'));

      await expectLater(
        service.syncFiles(),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message',
            contains('Google Drive API is disabled'))),
      );
    });

    test('syncFiles rethrows other DetailedApiRequestError statuses', () async {
      when(() => files.list(
            q: any(named: 'q'),
            $fields: any(named: r'$fields'),
            orderBy: any(named: 'orderBy'),
            pageSize: any(named: 'pageSize'),
          )).thenThrow(drive.DetailedApiRequestError(500, 'boom'));

      await expectLater(
        service.syncFiles(),
        throwsA(isA<drive.DetailedApiRequestError>()),
      );
    });

    test('syncFiles is a no-op when already syncing', () async {
      final gate = Completer<drive.FileList>();
      when(() => files.list(
            q: any(named: 'q'),
            $fields: any(named: r'$fields'),
            orderBy: any(named: 'orderBy'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((_) => gate.future);

      final first = service.syncFiles();
      await service.syncFiles();
      gate.completeError(Exception('cancel'));
      await first.catchError((_) {});
    });

    test('overwriteCloudWithLocal uploads new files and updates existing ones',
        () async {
      await File(p.join(tempDir.path, 'sessions.json')).writeAsString('[]');
      await File(p.join(tempDir.path, 'events.json')).writeAsString('[]');

      stubBasicFolders(childFiles: [
        _file('remote-sessions', 'sessions.json'),
      ]);
      var updates = 0;
      var creates = 0;
      when(() => files.update(any(), any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async {
        updates++;
        return _file('updated', 'updated');
      });
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async {
        creates++;
        return _file('created', 'created');
      });

      await service.overwriteCloudWithLocal();

      expect(updates, greaterThanOrEqualTo(1));
      expect(creates, greaterThanOrEqualTo(2));
      expect(service.lastSyncTime, isNotNull);
    });

    test('overwriteLocalWithCloud overwrites local files with remote content',
        () async {
      await File(p.join(tempDir.path, 'sessions.json')).writeAsString('old');

      stubBasicFolders(childFiles: [
        _file('remote-sessions', 'sessions.json'),
      ]);
      when(() => files.get('remote-sessions',
              downloadOptions: any(named: 'downloadOptions')))
          .thenAnswer((_) async => _media('[{"id":"new"}]'));
      when(() => files.get(any(), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => _file('remote-sessions', 'sessions.json',
              modifiedTime: DateTime.utc(2025, 5, 1)));
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('zip', 'zip'));

      await service.overwriteLocalWithCloud();

      final sessions =
          await File(p.join(tempDir.path, 'sessions.json')).readAsString();
      expect(sessions, '[{"id":"new"}]');
    });

    test('overwriteCloudWithLocal is a no-op when already syncing', () async {
      final gate = Completer<drive.FileList>();
      when(() => files.list(
            q: any(named: 'q'),
            $fields: any(named: r'$fields'),
            orderBy: any(named: 'orderBy'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((_) => gate.future);

      final first = service.overwriteCloudWithLocal();
      await service.overwriteCloudWithLocal();
      gate.completeError(Exception('cancel'));
      await first.catchError((_) {});
    });

    test('overwriteLocalWithCloud is a no-op when already syncing', () async {
      final gate = Completer<drive.FileList>();
      when(() => files.list(
            q: any(named: 'q'),
            $fields: any(named: r'$fields'),
            orderBy: any(named: 'orderBy'),
            pageSize: any(named: 'pageSize'),
          )).thenAnswer((_) => gate.future);

      final first = service.overwriteLocalWithCloud();
      await service.overwriteLocalWithCloud();
      gate.completeError(Exception('cancel'));
      await first.catchError((_) {});
    });

    test('restoreFromBackup extracts ZIP, merges with local and re-syncs',
        () async {
      final localFile = File(p.join(tempDir.path, 'sessions.json'));
      await localFile.writeAsString('[{"id":"existing"}]');

      final zipBytes = _zipOf('sessions.json', '[{"id":"restored"}]');

      when(() => files.get('backup-file-id',
              downloadOptions: any(named: 'downloadOptions')))
          .thenAnswer((_) async =>
              drive.Media(Stream.value(zipBytes), zipBytes.length));

      // The trailing syncFiles() call uses folder lookups + backup creation.
      stubBasicFolders();
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('zip', 'zip'));
      when(() => files.update(any(), any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('updated', 'updated'));

      await service.restoreFromBackup('backup-file-id',
          backupDateLabel: '2025-01-01');

      final merged = jsonDecode(await localFile.readAsString()) as List;
      final ids = merged.map((m) => (m as Map)['id']).toSet();
      expect(ids, containsAll({'existing', 'restored'}));
    });
  });
}
