import 'dart:convert';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:archive/archive_io.dart';
import 'package:app_device_integrity/app_device_integrity.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../data/session_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../hub/data/event_repository.dart';

class DriveService extends ChangeNotifier {
  DriveService({
    required GoogleSignIn googleSignIn,
    this.sessionRepository,
    this.attendanceRepository,
    this.eventRepository,
  }) : _googleSignIn = googleSignIn;

  final GoogleSignIn _googleSignIn;
  final SessionRepository? sessionRepository;
  final AttendanceRepository? attendanceRepository;
  final EventRepository? eventRepository;

  drive.DriveApi? _driveApi;
  DateTime? _lastSyncTime;
  bool _isSyncing = false;
  String? _appFolderId;
  String? _backupFolderId;

  static const String _syncFolderName = 'Attendance Tracker Data';
  static const String _backupFolderName = 'Backups';

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<void> _checkIntegrity() async {
    try {
      final String nonce = base64Url.encode(
        utf8.encode(DateTime.now().toIso8601String()),
      );
      final plugin = AppDeviceIntegrity();
      if (Platform.isAndroid) {
        await plugin.getAttestationServiceSupport(
          challengeString: nonce,
          gcp: YOUR_GOOGLE_PROJECT_NUMBER,
        );
      } else if (Platform.isIOS) {
        await plugin.getAttestationServiceSupport(
          challengeString: nonce,
        );
      }
      print('App Integrity check passed.');
    } catch (e) {
      print('App Integrity check failed: $e');
    }
  }

  Future<void> signIn() async {
    try {
      await _checkIntegrity();
      await _googleSignIn.signIn();
      await _initDriveApi();
      notifyListeners();
    } catch (e) {
      print('Sign in failed: $e');
      rethrow;
    }
  }

  Future<void> signInSilently() async {
    try {
      await _googleSignIn.signInSilently();
      if (_googleSignIn.currentUser != null) {
        await _initDriveApi();
      }
      notifyListeners();
    } catch (e) {
      print('Silent sign in failed: $e');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _driveApi = null;
    _appFolderId = null;
    _backupFolderId = null;
    notifyListeners();
  }

  Future<void> _initDriveApi() async {
    if (_driveApi != null) return;
    final client = await _googleSignIn.authenticatedClient();
    if (client != null) {
      _driveApi = drive.DriveApi(client);
    }
  }

  Future<String> _getOrCreateAppFolder() async {
    if (_appFolderId != null) return _appFolderId!;

    final query =
        "name = '$_syncFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final folderList = await _driveApi!.files.list(
      q: query,
      $fields: 'files(id)',
    );

    if (folderList.files != null && folderList.files!.isNotEmpty) {
      _appFolderId = folderList.files!.first.id;
      return _appFolderId!;
    }

    // Create folder
    final folder = drive.File()
      ..name = _syncFolderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final createdFolder = await _driveApi!.files.create(folder);
    _appFolderId = createdFolder.id;
    return _appFolderId!;
  }

  Future<String> _getOrCreateBackupFolder(String parentId) async {
    if (_backupFolderId != null) return _backupFolderId!;

    final query =
        "name = '$_backupFolderName' and '$parentId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final folderList = await _driveApi!.files.list(
      q: query,
      $fields: 'files(id)',
    );

    if (folderList.files != null && folderList.files!.isNotEmpty) {
      _backupFolderId = folderList.files!.first.id;
      return _backupFolderId!;
    }

    // Create folder
    final folder = drive.File()
      ..name = _backupFolderName
      ..parents = [parentId]
      ..mimeType = 'application/vnd.google-apps.folder';

    final createdFolder = await _driveApi!.files.create(folder);
    _backupFolderId = createdFolder.id;
    return _backupFolderId!;
  }

  Future<void> overwriteCloudWithLocal() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      await _initDriveApi();
      final folderId = await _getOrCreateAppFolder();
      final docsDir = await getApplicationDocumentsDirectory();
      final filesToSync = [
        'sessions.json',
        'families.json',
        'events.json',
        'sessions_history.json',
      ];

      final remoteFiles = await _listRemoteFiles(folderId);

      for (final fileName in filesToSync) {
        final localFile = File(p.join(docsDir.path, fileName));
        if (localFile.existsSync()) {
          final remoteFile = remoteFiles[fileName];
          if (remoteFile != null) {
            print('Overwriting remote $fileName...');
            await _updateFile(remoteFile.id!, localFile);
          } else {
            print('Uploading new remote $fileName...');
            await _uploadFile(localFile, fileName, folderId);
          }
        }
      }
      _lastSyncTime = DateTime.now();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> overwriteLocalWithCloud() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      await _initDriveApi();
      final folderId = await _getOrCreateAppFolder();
      final docsDir = await getApplicationDocumentsDirectory();
      final filesToSync = [
        'sessions.json',
        'families.json',
        'events.json',
        'sessions_history.json',
      ];

      final remoteFiles = await _listRemoteFiles(folderId);

      for (final fileName in filesToSync) {
        final remoteFile = remoteFiles[fileName];
        if (remoteFile != null) {
          final localFile = File(p.join(docsDir.path, fileName));
          print('Overwriting local $fileName...');
          await _downloadFile(remoteFile.id!, localFile);
        }
      }

      await Future.wait([
        if (sessionRepository != null) sessionRepository!.refresh(),
        if (attendanceRepository != null) attendanceRepository!.refresh(),
        if (eventRepository != null) eventRepository!.refresh(),
      ]);
      _lastSyncTime = DateTime.now();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> syncFiles() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      await _checkIntegrity();

      if (_driveApi == null) {
        // Try to initialize silently if signed in
        if (_googleSignIn.currentUser != null) {
          await _initDriveApi();
        } else {
          // Attempt silent sign in
          await _googleSignIn.signInSilently();
          await _initDriveApi();
        }
      }

      if (_driveApi == null) {
        throw Exception('Not signed in to Google Drive');
      }

      final folderId = await _getOrCreateAppFolder();

      final docsDir = await getApplicationDocumentsDirectory();
      final filesToSync = [
        'sessions.json',
        'families.json',
        'events.json',
        'sessions_history.json',
      ];

      // 1. Get remote files in our folder
      final remoteFiles = await _listRemoteFiles(folderId);

      // 2. Process each file
      for (final fileName in filesToSync) {
        final localFile = File(p.join(docsDir.path, fileName));
        final remoteFile = remoteFiles[fileName];

        if (!localFile.existsSync() && remoteFile != null) {
          // Remote exists, local doesn't -> Download
          print('Downloading $fileName...');
          await _downloadFile(remoteFile.id!, localFile);
        } else if (localFile.existsSync() && remoteFile == null) {
          // Local exists, remote doesn't -> Upload
          print('Uploading $fileName...');
          await _uploadFile(localFile, fileName, folderId);
        } else if (localFile.existsSync() && remoteFile != null) {
          // Both exist -> MERGE data
          print('Merging $fileName...');
          await _mergeAndSyncFile(
            remoteFile.id!,
            localFile,
            folderId,
            fileName,
          );
        }
      }

      _lastSyncTime = DateTime.now();
      // Refresh repositories to reflect synced changes in UI
      await Future.wait([
        if (sessionRepository != null) sessionRepository!.refresh(),
        if (attendanceRepository != null) attendanceRepository!.refresh(),
        if (eventRepository != null) eventRepository!.refresh(),
      ]);

      // 3. Create Cloud Backup snapshot
      await _createCloudBackup(folderId, docsDir, filesToSync);

      // TODO: Persist last sync time
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 403 &&
          e.message != null &&
          e.message!.contains('Google Drive API has not been used')) {
        print('Sync failed: Google Drive API is not enabled.');
        throw Exception(
          'Google Drive API is disabled. Enable it here: '
          'https://console.developers.google.com/apis/api/drive.googleapis.com/overview?project=YOUR_GOOGLE_PROJECT_NUMBER',
        );
      }
      print('Sync failed: DetailedApiRequestError(${e.status}, ${e.message})');
      rethrow;
    } catch (e) {
      print('Sync failed: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _createCloudBackup(
    String parentId,
    Directory docsDir,
    List<String> filesToBackup,
  ) async {
    try {
      final backupFolderId = await _getOrCreateBackupFolder(parentId);

      // Create ZIP
      final encoder = ZipFileEncoder();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupName = 'attendance_snapshot_$timestamp.zip';
      final backupPath = p.join(docsDir.path, backupName);
      encoder.create(backupPath);

      for (final fileName in filesToBackup) {
        final file = File(p.join(docsDir.path, fileName));
        if (await file.exists()) {
          encoder.addFile(file);
        }
      }
      encoder.close();

      // Upload ZIP
      final backupFile = File(backupPath);
      final media = drive.Media(backupFile.openRead(), backupFile.lengthSync());
      final driveFile = drive.File()
        ..name = backupName
        ..parents = [backupFolderId];

      await _driveApi!.files.create(driveFile, uploadMedia: media);

      // Cleanup local ZIP
      await backupFile.delete();

      // Maintain last 5 backups
      await _cleanupOldBackups(backupFolderId);
    } catch (e) {
      print('Failed to create cloud backup: $e');
    }
  }

  Future<void> _cleanupOldBackups(String folderId) async {
    final query =
        "'$folderId' in parents and trashed = false and name contains 'attendance_snapshot_'";
    final fileList = await _driveApi!.files.list(
      q: query,
      $fields: 'files(id, name, createdTime)',
      orderBy: 'createdTime desc',
    );

    if (fileList.files != null && fileList.files!.length > 5) {
      final filesToDelete = fileList.files!.sublist(5);
      for (final file in filesToDelete) {
        if (file.id != null) {
          await _driveApi!.files.delete(file.id!);
        }
      }
    }
  }

  Future<List<drive.File>> listCloudBackups() async {
    if (_driveApi == null) return [];
    final parentId = await _getOrCreateAppFolder();
    final backupFolderId = await _getOrCreateBackupFolder(parentId);

    final query =
        "'$backupFolderId' in parents and trashed = false and name contains 'attendance_snapshot_'";
    final fileList = await _driveApi!.files.list(
      q: query,
      $fields: 'files(id, name, createdTime, size)',
      orderBy: 'createdTime desc',
    );

    return fileList.files ?? [];
  }

  Future<void> restoreFromBackup(String fileId) async {
    if (_driveApi == null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final tempBackup = File(p.join(docsDir.path, 'restore_temp.zip'));

    // 1. Download ZIP
    final media =
        await _driveApi!.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final List<int> bytes = [];
    await media.stream.forEach(bytes.addAll);
    await tempBackup.writeAsBytes(bytes);

    // 2. Extract
    final archive = ZipDecoder().decodeBytes(await tempBackup.readAsBytes());
    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        File(p.join(docsDir.path, filename))
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      }
    }

    // 3. Cleanup
    await tempBackup.delete();

    // 4. Refresh
    await Future.wait([
      if (sessionRepository != null) sessionRepository!.refresh(),
      if (attendanceRepository != null) attendanceRepository!.refresh(),
      if (eventRepository != null) eventRepository!.refresh(),
    ]);
    notifyListeners();
  }

  Future<Map<String, drive.File>> _listRemoteFiles(String folderId) async {
    final query =
        "'$folderId' in parents and trashed = false and mimeType != 'application/vnd.google-apps.folder'";
    final fileList = await _driveApi!.files.list(
      q: query,
      $fields: 'files(id, name, modifiedTime)',
    );

    final map = <String, drive.File>{};
    if (fileList.files != null) {
      for (final file in fileList.files!) {
        if (file.name != null) {
          // Handle duplicates? Just take the first one or latest.
          // drive.file scope limits visibility, so we might not see duplicates from other apps.
          // But if we uploaded multiple times, we might have duplicates.
          // Let's assume we handle duplicates by taking the most recent one.
          if (!map.containsKey(file.name) ||
              map[file.name]!.modifiedTime!.isBefore(file.modifiedTime!)) {
            map[file.name!] = file;
          }
        }
      }
    }
    return map;
  }

  Future<void> _uploadFile(File localFile, String name, String folderId) async {
    final media = drive.Media(localFile.openRead(), localFile.lengthSync());
    final driveFile = drive.File()
      ..name = name
      ..parents = [folderId];

    await _driveApi!.files.create(driveFile, uploadMedia: media);
  }

  Future<void> _updateFile(String fileId, File localFile) async {
    final media = drive.Media(localFile.openRead(), localFile.lengthSync());
    // update modifiedTime explicitly? Drive updates it automatically.
    await _driveApi!.files.update(drive.File(), fileId, uploadMedia: media);
  }

  Future<void> _mergeAndSyncFile(
    String fileId,
    File localFile,
    String folderId,
    String fileName,
  ) async {
    // 1. Download remote data
    final media =
        await _driveApi!.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final List<int> remoteBytes = [];
    await media.stream.forEach(remoteBytes.addAll);
    final remoteContent = utf8.decode(remoteBytes);

    // 2. Load local data
    final localContent = await localFile.readAsString();

    try {
      final remoteJson = jsonDecode(remoteContent);

      // CRITICAL: Integrity Check
      // We check if the remote data matches the expected type for the file.
      final isHistoryFile = fileName == 'sessions_history.json';
      final bool isValidRemote = isHistoryFile
          ? remoteJson is Map<String, dynamic>
          : remoteJson is List;

      if (!isValidRemote) {
        throw FormatException(
          'Remote data for $fileName is not a valid ${isHistoryFile ? 'Map' : 'List'}',
        );
      }

      final localJson = jsonDecode(localContent);
      final bool isValidLocal = isHistoryFile
          ? localJson is Map<String, dynamic>
          : localJson is List;

      if (isValidLocal) {
        // Perform merge
        dynamic mergedJson;
        if (isHistoryFile) {
          mergedJson = _mergeHistoryMaps(
            localJson as Map<String, dynamic>,
            remoteJson as Map<String, dynamic>,
          );
        } else {
          mergedJson = _mergeJsonLists(
            localJson as List,
            remoteJson as List,
            fileName,
          );
        }
        final mergedContent = jsonEncode(mergedJson);

        // 3. Update local
        await localFile.writeAsString(mergedContent);

        // 4. Update remote
        final updatedMedia = drive.Media(
          Stream.value(utf8.encode(mergedContent)),
          utf8.encode(mergedContent).length,
        );
        await _driveApi!.files.update(
          drive.File(),
          fileId,
          uploadMedia: updatedMedia,
        );

        // Update local mod time to match remote
        final remoteFile =
            await _driveApi!.files.get(fileId, $fields: 'modifiedTime')
                as drive.File;
        if (remoteFile.modifiedTime != null) {
          await localFile.setLastModified(remoteFile.modifiedTime!);
        }
      } else {
        // Local is corrupted? Repository recovery logic will handle this usually,
        // but here we just fallback to time-based.
        await _timeBasedSync(fileId, localFile, folderId, fileName);
      }
    } catch (e) {
      print('Sync integrity check failed for $fileName: $e');
      // HEALING PATH:
      // If remote is corrupted (Format/Decode error), force upload local to "heal" cloud.
      // Only do this if local is healthy.
      try {
        final localCheck = jsonDecode(localContent);
        if (localCheck is List) {
          print('Local data is healthy. Healing cloud with local copy.');
          await _updateFile(fileId, localFile);
        }
      } catch (localError) {
        print('Both local and remote corrupted. Manual restore required.');
      }
    }
  }

  Future<void> _timeBasedSync(
    String fileId,
    File localFile,
    String folderId,
    String fileName,
  ) async {
    final localModTime = await localFile.lastModified();
    final remoteFile =
        await _driveApi!.files.get(fileId, $fields: 'modifiedTime')
            as drive.File;
    final remoteModTime = remoteFile.modifiedTime;

    if (remoteModTime != null &&
        remoteModTime.isAfter(localModTime.add(const Duration(seconds: 5)))) {
      await _downloadFile(fileId, localFile);
    } else if (localModTime.isAfter(
      remoteModTime!.add(const Duration(seconds: 5)),
    )) {
      await _updateFile(fileId, localFile);
    }
  }

  Map<String, dynamic> _mergeHistoryMaps(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final Map<String, dynamic> merged = {};

    final allSessionIds = {...local.keys, ...remote.keys};

    for (final sessionId in allSessionIds) {
      final localVersions = local[sessionId] as List? ?? [];
      final remoteVersions = remote[sessionId] as List? ?? [];

      // Merge versions by version number
      final Map<int, dynamic> mergedVersions = {};
      for (final v in [...remoteVersions, ...localVersions]) {
        if (v is Map && v.containsKey('version')) {
          final ver = v['version'] as int;
          // If we have duplicates, we could compare recordedAt, but version numbers should be consistent.
          // For safety, prefer the one with a later recordedAt if available.
          if (!mergedVersions.containsKey(ver)) {
            mergedVersions[ver] = v;
          } else {
            final existing = mergedVersions[ver] as Map;
            final current = v;
            if (current.containsKey('recordedAt') &&
                existing.containsKey('recordedAt')) {
              final currentRec = DateTime.parse(current['recordedAt']);
              final existingRec = DateTime.parse(existing['recordedAt']);
              if (currentRec.isAfter(existingRec)) {
                mergedVersions[ver] = v;
              }
            }
          }
        }
      }

      final sortedVersions = mergedVersions.values.toList();
      // Sort newer first (descending version)
      sortedVersions.sort((a, b) => (b['version'] as int).compareTo(a['version'] as int));
      merged[sessionId] = sortedVersions;
    }

    return merged;
  }

  List<dynamic> _mergeJsonLists(
    List<dynamic> local,
    List<dynamic> remote,
    String fileName,
  ) {
    final Map<String, dynamic> merged = {};

    void process(List<dynamic> list) {
      for (final item in list) {
        if (item is Map && item.containsKey('id')) {
          final id = item['id'] as String;
          if (!merged.containsKey(id)) {
            merged[id] = item;
          } else {
            // Tie-break: Use updatedAt if available
            final existing = merged[id] as Map;
            final current = item;

            if (current.containsKey('updatedAt') &&
                existing.containsKey('updatedAt')) {
              final currentUpdate = DateTime.parse(current['updatedAt']);
              final existingUpdate = DateTime.parse(existing['updatedAt']);
              if (currentUpdate.isAfter(existingUpdate)) {
                merged[id] = item;
              }
            } else if (fileName == 'families.json') {
              // For families, merge member lists
              final mergedMembers = _mergeJsonLists(
                existing['members'] as List? ?? [],
                current['members'] as List? ?? [],
                'members',
              );
              merged[id] = {...existing, 'members': mergedMembers};
            }
          }
        }
      }
    }

    process(remote);
    process(local);

    return merged.values.toList();
  }

  Future<void> _downloadFile(String fileId, File localFile) async {
    final media =
        await _driveApi!.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final List<int> dataStore = [];
    await media.stream.forEach((data) {
      dataStore.addAll(data);
    });

    await localFile.writeAsBytes(dataStore);

    final remoteFile =
        await _driveApi!.files.get(fileId, $fields: 'modifiedTime')
            as drive.File;
    if (remoteFile.modifiedTime != null) {
      await localFile.setLastModified(remoteFile.modifiedTime!);
    }
  }

  @visibleForTesting
  List<dynamic> testMergeJsonLists(
    List<dynamic> local,
    List<dynamic> remote,
    String fileName,
  ) {
    return _mergeJsonLists(local, remote, fileName);
  }

  @visibleForTesting
  Map<String, dynamic> testMergeHistoryMaps(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    return _mergeHistoryMaps(local, remote);
  }
}
