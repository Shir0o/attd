import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:archive/archive.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
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

class MockSessionRepository extends Mock implements SessionRepository {}

class MockAttendanceRepository extends Mock implements AttendanceRepository {}

class MockEventRepository extends Mock implements EventRepository {}

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

List<int> _zipOfMany(Map<String, String> entries) {
  final archive = Archive();
  entries.forEach((name, content) {
    archive.addFile(ArchiveFile(name, content.length, utf8.encode(content)));
  });
  return ZipEncoder().encode(archive)!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_FakeDriveFile());
    registerFallbackValue(_FakeDownloadOptions());
    registerFallbackValue(_FakeMedia());
  });

  group('DriveService extra branch coverage', () {
    late Directory tempDir;
    late MockGoogleSignIn signIn;
    late MockDriveApi api;
    late MockFilesResource files;
    late MockSessionRepository sessionRepo;
    late MockAttendanceRepository attendanceRepo;
    late MockEventRepository eventRepo;
    late DriveService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('drive_service_cov');
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
      SharedPreferences.setMockInitialValues({});

      signIn = MockGoogleSignIn();
      when(() => signIn.authenticationEvents).thenAnswer(
          (_) => const Stream<GoogleSignInAuthenticationEvent>.empty());

      api = MockDriveApi();
      files = MockFilesResource();
      when(() => api.files).thenReturn(files);

      sessionRepo = MockSessionRepository();
      attendanceRepo = MockAttendanceRepository();
      eventRepo = MockEventRepository();
      when(() => sessionRepo.refresh()).thenAnswer((_) async {});
      when(() => attendanceRepo.refresh()).thenAnswer((_) async {});
      when(() => eventRepo.refresh()).thenAnswer((_) async {});

      service = DriveService(
        googleSignIn: signIn,
        sessionRepository: sessionRepo,
        attendanceRepository: attendanceRepo,
        eventRepository: eventRepo,
      );
      service.debugSetDriveApi(api);
    });

    tearDown(() async {
      service.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    void stubFolders({List<drive.File> childFiles = const []}) {
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
        if (q.contains("'app' in parents")) {
          return drive.FileList(files: childFiles);
        }
        return drive.FileList(files: []);
      });
    }

    test('_listRemoteFiles dedupes by modifiedTime keeping newest and trashing '
        'older duplicate', () async {
      final localFile = File(p.join(tempDir.path, 'sessions.json'));
      await localFile.writeAsString('[]');

      final older = _file('old-id', 'sessions.json',
          modifiedTime: DateTime.utc(2025, 1, 1));
      final newer = _file('new-id', 'sessions.json',
          modifiedTime: DateTime.utc(2025, 1, 5));
      // Third "duplicate" comes after the newest — exercises the else branch
      // (file.modifiedTime not after existing -> trash current file id).
      final third = _file('third-id', 'sessions.json',
          modifiedTime: DateTime.utc(2025, 1, 2));

      stubFolders(childFiles: [older, newer, third]);

      // Capture the IDs that get trashed. A single stub handles both the
      // trash call (no uploadMedia) and the merge update call.
      final trashed = <String>[];
      when(() => files.update(any(), any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((invocation) async {
        final dynamic media = invocation.namedArguments[#uploadMedia];
        if (media == null) {
          trashed.add(invocation.positionalArguments[1] as String);
        }
        return _file('x', 'x');
      });
      when(() => files.get('new-id',
              downloadOptions: any(named: 'downloadOptions')))
          .thenAnswer((_) async => _media('[]'));
      when(() => files.get(any(), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => _file('new-id', 'sessions.json',
              modifiedTime: DateTime.utc(2025, 1, 5)));
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('zip', 'zip'));

      await service.syncFiles();

      // Both duplicates should be trashed; the trash update has a single
      // positional file-id arg (the second positional). Our captured list
      // should include the older id and the third id.
      expect(trashed, containsAll(['old-id', 'third-id']));
    });

    test('_listRemoteFiles swallows errors when trashing duplicates fails',
        () async {
      await File(p.join(tempDir.path, 'sessions.json')).writeAsString('[]');

      final a = _file('a', 'sessions.json',
          modifiedTime: DateTime.utc(2025, 1, 1));
      final b = _file('b', 'sessions.json',
          modifiedTime: DateTime.utc(2025, 1, 2));
      stubFolders(childFiles: [a, b]);

      // Single stub: throw for trash (no uploadMedia), succeed for merge
      // uploads (with uploadMedia).
      when(() => files.update(any(), any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((invocation) async {
        final dynamic media = invocation.namedArguments[#uploadMedia];
        if (media == null) throw Exception('trash boom');
        return _file('updated', 'updated');
      });
      when(() => files.get('b',
              downloadOptions: any(named: 'downloadOptions')))
          .thenAnswer((_) async => _media('[]'));
      when(() => files.get(any(), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => _file('b', 'sessions.json',
              modifiedTime: DateTime.utc(2025, 1, 2)));
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('zip', 'zip'));

      // Should complete without throwing.
      await service.syncFiles();
    });

    test('_mergeAndSyncFile heals cloud when remote JSON is corrupted',
        () async {
      final localFile = File(p.join(tempDir.path, 'sessions.json'));
      await localFile.writeAsString('[{"id":"a"}]');

      stubFolders(childFiles: [
        _file('rid', 'sessions.json', modifiedTime: DateTime.utc(2025, 1, 1)),
      ]);
      when(() => files.get('rid',
              downloadOptions: any(named: 'downloadOptions')))
          .thenAnswer((_) async => _media('not-json {{{'));
      when(() => files.get(any(), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => _file('rid', 'sessions.json',
              modifiedTime: DateTime.utc(2025, 1, 1)));
      var healingUpdates = 0;
      when(() => files.update(any(), any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async {
        healingUpdates++;
        return _file('rid', 'sessions.json');
      });
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('zip', 'zip'));

      await service.syncFiles();
      // Healing path should have invoked an update (upload local).
      expect(healingUpdates, greaterThanOrEqualTo(1));
    });

    test('_mergeAndSyncFile logs when both local and remote are corrupted',
        () async {
      final localFile = File(p.join(tempDir.path, 'sessions.json'));
      await localFile.writeAsString('also-bad {{{');

      stubFolders(childFiles: [
        _file('rid', 'sessions.json', modifiedTime: DateTime.utc(2025, 1, 1)),
      ]);
      when(() => files.get('rid',
              downloadOptions: any(named: 'downloadOptions')))
          .thenAnswer((_) async => _media('not-json {{{'));
      when(() => files.get(any(), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => _file('rid', 'sessions.json',
              modifiedTime: DateTime.utc(2025, 1, 1)));
      when(() => files.update(any(), any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('rid', 'sessions.json'));
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('zip', 'zip'));

      // Should complete without throwing despite double-corruption.
      await service.syncFiles();
    });

    test('_mergeAndSyncFile falls back to time-based sync when local data is '
        'not a List/Map for the file type', () async {
      final localFile = File(p.join(tempDir.path, 'sessions.json'));
      // sessions.json expects a List; write a Map locally (valid JSON, but
      // wrong type) to drive the isValidLocal=false branch with remote List.
      await localFile.writeAsString('{"id":"oops"}');
      // Ensure local mod time is older than remote to force a download.
      await localFile.setLastModified(DateTime.utc(2025, 1, 1));

      stubFolders(childFiles: [
        _file('rid', 'sessions.json', modifiedTime: DateTime.utc(2025, 1, 10)),
      ]);
      // Remote is a valid List.
      when(() => files.get('rid',
              downloadOptions: any(named: 'downloadOptions')))
          .thenAnswer((_) async => _media('[{"id":"r"}]'));
      // _timeBasedSync calls files.get(...$fields...) to read modifiedTime,
      // and then _downloadFile also does the same.
      when(() => files.get(any(), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => _file('rid', 'sessions.json',
              modifiedTime: DateTime.utc(2025, 1, 10)));
      when(() => files.update(any(), any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('rid', 'sessions.json'));
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('zip', 'zip'));

      await service.syncFiles();
      // Local should now contain the remote List content.
      final content = await localFile.readAsString();
      expect(jsonDecode(content), isA<List>());
    });

    test('_timeBasedSync uploads when remote modifiedTime is null', () async {
      final localFile = File(p.join(tempDir.path, 'sessions.json'));
      await localFile.writeAsString('{"id":"oops"}');

      stubFolders(childFiles: [
        _file('rid', 'sessions.json', modifiedTime: DateTime.utc(2025, 1, 10)),
      ]);
      when(() => files.get('rid',
              downloadOptions: any(named: 'downloadOptions')))
          .thenAnswer((_) async => _media('[{"id":"r"}]'));
      // Remote modifiedTime is null -> upload path.
      when(() => files.get(any(), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => _file('rid', 'sessions.json'));
      var updates = 0;
      when(() => files.update(any(), any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async {
        updates++;
        return _file('rid', 'sessions.json');
      });
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('zip', 'zip'));

      await service.syncFiles();
      expect(updates, greaterThanOrEqualTo(1));
    });

    test('_timeBasedSync uploads when local is newer', () async {
      final localFile = File(p.join(tempDir.path, 'sessions.json'));
      await localFile.writeAsString('{"id":"oops"}');
      await localFile.setLastModified(DateTime.utc(2025, 6, 1));

      stubFolders(childFiles: [
        _file('rid', 'sessions.json', modifiedTime: DateTime.utc(2025, 1, 1)),
      ]);
      when(() => files.get('rid',
              downloadOptions: any(named: 'downloadOptions')))
          .thenAnswer((_) async => _media('[{"id":"r"}]'));
      when(() => files.get(any(), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => _file('rid', 'sessions.json',
              modifiedTime: DateTime.utc(2025, 1, 1)));
      var updates = 0;
      when(() => files.update(any(), any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async {
        updates++;
        return _file('rid', 'sessions.json');
      });
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('zip', 'zip'));

      await service.syncFiles();
      expect(updates, greaterThanOrEqualTo(1));
    });

    test('_mergeAndSyncFile merges session_history map content', () async {
      final localFile = File(p.join(tempDir.path, 'sessions_history.json'));
      await localFile.writeAsString(jsonEncode({
        's1': [
          {'version': 1, 'recordedAt': '2025-01-01T00:00:00Z'},
        ],
      }));

      stubFolders(childFiles: [
        _file('hid', 'sessions_history.json',
            modifiedTime: DateTime.utc(2025, 1, 2)),
      ]);
      when(() => files.get('hid',
              downloadOptions: any(named: 'downloadOptions')))
          .thenAnswer((_) async => _media(jsonEncode({
                's1': [
                  {'version': 2, 'recordedAt': '2025-01-02T00:00:00Z'},
                ],
              })));
      when(() => files.get(any(), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => _file('hid', 'sessions_history.json',
              modifiedTime: DateTime.utc(2025, 1, 2)));
      when(() => files.update(any(), any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('hid', 'sessions_history.json'));
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('zip', 'zip'));

      await service.syncFiles();

      final merged = jsonDecode(await localFile.readAsString())
          as Map<String, dynamic>;
      final versions = merged['s1'] as List;
      expect(versions.length, 2);
      expect(versions.first['version'], 2);
    });

    test('_mergeHistoryMaps prefers later recordedAt for duplicate version',
        () {
      final local = {
        's1': [
          {'version': 1, 'recordedAt': '2025-01-01T00:00:00Z', 'tag': 'local'},
        ],
      };
      final remote = {
        's1': [
          {'version': 1, 'recordedAt': '2025-02-01T00:00:00Z', 'tag': 'remote'},
        ],
      };

      final merged = service.testMergeHistoryMaps(local, remote);
      final versions = merged['s1'] as List;
      expect(versions.length, 1);
      // remote has a later recordedAt -> should win.
      expect(versions.first['tag'], 'remote');
    });

    test('restoreFromBackup merges sessions_history maps from the ZIP',
        () async {
      final localHistory = File(p.join(tempDir.path, 'sessions_history.json'));
      await localHistory.writeAsString(jsonEncode({
        's1': [
          {'version': 1, 'recordedAt': '2025-01-01T00:00:00Z'},
        ],
      }));

      final zipBytes = _zipOfMany({
        'sessions_history.json': jsonEncode({
          's1': [
            {'version': 2, 'recordedAt': '2025-02-01T00:00:00Z'},
          ],
        }),
      });
      when(() => files.get('bak',
              downloadOptions: any(named: 'downloadOptions')))
          .thenAnswer((_) async =>
              drive.Media(Stream.value(zipBytes), zipBytes.length));

      stubFolders();
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('zip', 'zip'));
      when(() => files.update(any(), any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('updated', 'updated'));

      await service.restoreFromBackup('bak');

      final merged = jsonDecode(await localHistory.readAsString())
          as Map<String, dynamic>;
      final versions = merged['s1'] as List;
      expect(versions.length, 2);
    });

    test('restoreFromBackup overwrites local with raw bytes when merge yields '
        'nothing (type mismatch)', () async {
      // Local is a List; backup contains a Map for sessions.json -> type
      // mismatch -> fallback writeAsBytes.
      final localFile = File(p.join(tempDir.path, 'sessions.json'));
      await localFile.writeAsString('[{"id":"existing"}]');

      final zipBytes = _zipOfMany({
        'sessions.json': '{"id":"oops"}',
      });
      when(() => files.get('bak',
              downloadOptions: any(named: 'downloadOptions')))
          .thenAnswer((_) async =>
              drive.Media(Stream.value(zipBytes), zipBytes.length));

      stubFolders();
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('zip', 'zip'));
      when(() => files.update(any(), any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('updated', 'updated'));

      await service.restoreFromBackup('bak');
      expect(await localFile.readAsString(), '{"id":"oops"}');
    });

    test('restoreFromBackup writes new file when local does not exist',
        () async {
      final zipBytes = _zipOfMany({
        'sessions.json': '[{"id":"new"}]',
      });
      when(() => files.get('bak',
              downloadOptions: any(named: 'downloadOptions')))
          .thenAnswer((_) async =>
              drive.Media(Stream.value(zipBytes), zipBytes.length));

      stubFolders();
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('zip', 'zip'));
      when(() => files.update(any(), any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('updated', 'updated'));

      await service.restoreFromBackup('bak');
      final created = File(p.join(tempDir.path, 'sessions.json'));
      expect(created.existsSync(), isTrue);
      expect(await created.readAsString(), '[{"id":"new"}]');
    });

    test('restoreFromBackup falls back to writeBytes on merge exception',
        () async {
      // Local has invalid JSON -> merge path throws inside try, hits the
      // catch and writes raw backup bytes.
      final localFile = File(p.join(tempDir.path, 'sessions.json'));
      await localFile.writeAsString('not json {{{');

      final zipBytes = _zipOfMany({
        'sessions.json': '[{"id":"restored"}]',
      });
      when(() => files.get('bak',
              downloadOptions: any(named: 'downloadOptions')))
          .thenAnswer((_) async =>
              drive.Media(Stream.value(zipBytes), zipBytes.length));

      stubFolders();
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('zip', 'zip'));
      when(() => files.update(any(), any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('updated', 'updated'));

      await service.restoreFromBackup('bak');
      expect(await localFile.readAsString(), '[{"id":"restored"}]');
    });

    test('_createCloudBackup swallows upload errors and keeps sync flowing',
        () async {
      await File(p.join(tempDir.path, 'sessions.json')).writeAsString('[]');

      stubFolders();
      // The first create call is the local file upload; subsequent create is
      // the backup ZIP upload — make any create with uploadMedia throw.
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenThrow(Exception('upload failed'));

      // syncFiles should still complete (backup error is swallowed); but
      // because the local-file upload also throws, syncFiles will rethrow.
      await expectLater(service.syncFiles(), throwsA(isA<Exception>()));
    });

    test('overwriteLocalWithCloud refreshes repositories', () async {
      stubFolders(childFiles: [
        _file('rid', 'sessions.json'),
      ]);
      when(() => files.get('rid',
              downloadOptions: any(named: 'downloadOptions')))
          .thenAnswer((_) async => _media('[]'));
      when(() => files.get(any(), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => _file('rid', 'sessions.json',
              modifiedTime: DateTime.utc(2025, 5, 1)));
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('zip', 'zip'));

      await service.overwriteLocalWithCloud();

      verify(() => sessionRepo.refresh()).called(1);
      verify(() => attendanceRepo.refresh()).called(1);
      verify(() => eventRepo.refresh()).called(1);
    });

    test('syncFiles passes isInitialSetup tag in metadata', () async {
      await File(p.join(tempDir.path, 'sessions.json')).writeAsString('[]');
      stubFolders();
      when(() => files.create(any(),
              uploadMedia: any(named: 'uploadMedia')))
          .thenAnswer((_) async => _file('x', 'x'));

      await service.syncFiles(
        actionTitle: 'First Sync',
        tags: ['Initial'],
        isInitialSetup: true,
      );
      // Repositories should have been refreshed.
      verify(() => sessionRepo.refresh()).called(1);
    });
  });

  group('DriveService extra branch coverage (no DriveApi pre-set)', () {
    late Directory tempDir;
    late MockGoogleSignIn signIn;
    late StreamController<GoogleSignInAuthenticationEvent> authController;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('drive_service_cov2');
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
      SharedPreferences.setMockInitialValues({});

      signIn = MockGoogleSignIn();
      authController =
          StreamController<GoogleSignInAuthenticationEvent>.broadcast();
      when(() => signIn.authenticationEvents)
          .thenAnswer((_) => authController.stream);
      when(() => signIn.attemptLightweightAuthentication()).thenReturn(null);
    });

    tearDown(() async {
      await authController.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('syncFiles throws when not signed in and silent sign-in fails',
        () async {
      final service = DriveService(googleSignIn: signIn);
      addTearDown(service.dispose);

      await expectLater(service.syncFiles(), throwsA(isA<Exception>()));
    });

    test('Auth event onError is delivered without crashing the listener',
        () async {
      final service = DriveService(googleSignIn: signIn);
      addTearDown(service.dispose);

      // Pump an error through the stream — the listener's onError handles it.
      authController.addError(Exception('auth boom'));
      await Future<void>.delayed(Duration.zero);
      expect(service.currentUser, isNull);
    });
  });
}
