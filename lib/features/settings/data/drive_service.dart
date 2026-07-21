import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:archive/archive_io.dart';
import 'package:app_attest_integrity/app_attest_integrity.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../data/session_repository.dart';
import '../../../core/logging/app_logger.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../hub/data/event_repository.dart';

final _log = AppLogger('DriveService');

class SyncStats {
  int newSessions = 0;
  int newEvents = 0;
  int newMembers = 0;
  int newFamilies = 0;

  bool get hasChanges =>
      newSessions > 0 || newEvents > 0 || newMembers > 0 || newFamilies > 0;

  List<String> toTags() {
    final tags = <String>[];
    if (newSessions > 0) tags.add('+$newSessions Sessions');
    if (newEvents > 0) tags.add('+$newEvents Events');
    if (newMembers > 0) tags.add('+$newMembers Members');
    if (newFamilies > 0) tags.add('+$newFamilies Families');
    return tags;
  }
}

class DriveService extends ChangeNotifier {
  DriveService({
    GoogleSignIn? googleSignIn,
    this.sessionRepository,
    this.attendanceRepository,
    this.eventRepository,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance {
    // v7: Track current user via the authenticationEvents stream rather
    // than the removed `currentUser` getter.
    _authSubscription = _googleSignIn.authenticationEvents.listen(
      _handleAuthEvent,
      onError: (Object e) => _log.warning('Auth event error', e),
    );
  }

  final GoogleSignIn _googleSignIn;
  final SessionRepository? sessionRepository;
  final AttendanceRepository? attendanceRepository;
  final EventRepository? eventRepository;

  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;
  GoogleSignInAccount? _currentUser;
  GoogleSignInClientAuthorization? _authorization;

  drive.DriveApi? _driveApi;
  DateTime? _lastSyncTime;
  bool _isSyncing = false;
  String? _appFolderId;
  String? _backupFolderId;
  bool _isDriveSyncEnabled = false;

  // Drive scope used for app-managed files. driveFileScope is the most
  // privacy-preserving option that still allows full create/read/write
  // on files this app creates.
  static const List<String> _driveScopes = <String>[drive.DriveApi.driveFileScope];

  static const String _syncFolderName = 'Attendance Tracker Data';
  static const String _backupFolderName = 'Backups';
  static const String _syncEnabledKey = 'drive_sync_enabled';
  static const String _lastSyncTimeKey = 'drive_last_sync_time';
  static const String backgroundSyncEnabledKey = 'background_sync_enabled';
  static const String backgroundSyncWifiOnlyKey = 'background_sync_wifi_only';
  static const String lastBackgroundSyncTimeKey = 'last_background_sync_time';
  static const String lastBackgroundSyncStatusKey = 'last_background_sync_status';

  // Read Google Project Number from environment variable via --dart-define or --dart-define-from-file
  static const int yourGoogleProjectNumber = int.fromEnvironment(
    'GOOGLE_CLOUD_PROJECT_NUMBER',
    defaultValue: 0,
  );

  bool _isBackgroundSyncEnabled = true;
  bool _isBackgroundSyncWifiOnly = true;
  DateTime? _lastBackgroundSyncTime;
  String? _lastBackgroundSyncStatus;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isDriveSyncEnabled => _isDriveSyncEnabled;
  bool get isBackgroundSyncEnabled => _isBackgroundSyncEnabled;
  bool get isBackgroundSyncWifiOnly => _isBackgroundSyncWifiOnly;
  DateTime? get lastBackgroundSyncTime => _lastBackgroundSyncTime;
  String? get lastBackgroundSyncStatus => _lastBackgroundSyncStatus;

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _handleAuthEvent(GoogleSignInAuthenticationEvent event) {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn():
        _currentUser = event.user;
      case GoogleSignInAuthenticationEventSignOut():
        _currentUser = null;
        _authorization = null;
        _driveApi = null;
    }
    notifyListeners();
  }

  Future<void> setDriveSyncEnabled(bool enabled) async {
    _isDriveSyncEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncEnabledKey, enabled);
    notifyListeners();
    if (enabled) {
      syncFiles().catchError(
        (e) => _log.error('Sync failed after enabling', e as Object),
      );
    }
  }

  Future<void> setBackgroundSyncEnabled(bool enabled) async {
    _isBackgroundSyncEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(backgroundSyncEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setBackgroundSyncWifiOnly(bool wifiOnly) async {
    _isBackgroundSyncWifiOnly = wifiOnly;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(backgroundSyncWifiOnlyKey, wifiOnly);
    notifyListeners();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDriveSyncEnabled = prefs.getBool(_syncEnabledKey) ?? false;
    _isBackgroundSyncEnabled = prefs.getBool(backgroundSyncEnabledKey) ?? true;
    _isBackgroundSyncWifiOnly = prefs.getBool(backgroundSyncWifiOnlyKey) ?? true;

    final lastSyncStr = prefs.getString(_lastSyncTimeKey);
    if (lastSyncStr != null) {
      _lastSyncTime = DateTime.tryParse(lastSyncStr);
    }

    final lastBgSyncStr = prefs.getString(lastBackgroundSyncTimeKey);
    if (lastBgSyncStr != null) {
      _lastBackgroundSyncTime = DateTime.tryParse(lastBgSyncStr);
    }
    _lastBackgroundSyncStatus = prefs.getString(lastBackgroundSyncStatusKey);

    if (_isDriveSyncEnabled) {
      await signInSilently();
      if (currentUser != null) {
        // Only trigger sync if we successfully signed in
        syncFiles().catchError(
          (e) => _log.error('Initial sync failed', e as Object),
        );
      }
    }
  }


  Future<void> _checkIntegrity() async {
    try {
      if (Platform.isAndroid && yourGoogleProjectNumber == 0) {
        _log.warning(
          'GOOGLE_CLOUD_PROJECT_NUMBER not set; Play Integrity API will fail.',
        );
        return; // Fail gracefully
      }
      final String nonce = base64Url.encode(
        utf8.encode(DateTime.now().toIso8601String()),
      );
      const plugin = AppAttestIntegrity();
      if (Platform.isAndroid) {
        await plugin.verify(
          clientData: nonce,
          androidCloudProjectNumber: yourGoogleProjectNumber,
        );
      } else if (Platform.isIOS) {
        await plugin.verify(clientData: nonce);
      }
      _log.info('App Integrity check passed.');
    } catch (e, st) {
      _log.warning('App Integrity check failed', e, st);
    }
  }

  Future<void> signIn() async {
    try {
      await _checkIntegrity();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw UnsupportedError(
          'Interactive Google Sign-In is not supported on this platform.',
        );
      }
      // v7: authenticate() handles authentication only. The returned
      // account is also delivered via the authenticationEvents stream
      // which updates _currentUser through _handleAuthEvent.
      final account = await _googleSignIn.authenticate();
      _currentUser = account;
      await _ensureAuthorization(account);
      await _initDriveApi();
      _isDriveSyncEnabled = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_syncEnabledKey, true);
      notifyListeners();
    } catch (e, st) {
      _log.warning('Sign in failed', e, st);
      rethrow;
    }
  }

  Future<void> signInSilently() async {
    try {
      // v7: attemptLightweightAuthentication replaces signInSilently.
      // It can return null synchronously on some platforms (hence the ?).
      final result = _googleSignIn.attemptLightweightAuthentication();
      final account = result == null ? null : await result;
      if (account != null) {
        _currentUser = account;
        // Silent path: only use cached authorization. Do NOT call
        // authorizeScopes(), which would prompt for consent.
        _authorization = await account.authorizationClient
            .authorizationForScopes(_driveScopes);
        if (_authorization != null) {
          await _initDriveApi();
        }
      }
      notifyListeners();
    } catch (e) {
      _log.info('Silent sign in failed: $e');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _authorization = null;
    _driveApi = null;
    _appFolderId = null;
    _backupFolderId = null;
    _isDriveSyncEnabled = false;
    _lastSyncTime = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncEnabledKey, false);
    await prefs.remove(_lastSyncTimeKey);
    notifyListeners();
  }

  /// Ensures we hold a valid [GoogleSignInClientAuthorization] for the
  /// Drive scopes, requesting interactive consent only if needed.
  Future<void> _ensureAuthorization(GoogleSignInAccount account) async {
    var auth = await account.authorizationClient
        .authorizationForScopes(_driveScopes);
    auth ??= await account.authorizationClient.authorizeScopes(_driveScopes);
    _authorization = auth;
  }

  Future<void> _saveLastSyncTime(DateTime time) async {
    _lastSyncTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncTimeKey, time.toIso8601String());
  }

  Future<void> _initDriveApi() async {
    if (_driveApi != null) return;
    if (_authorization == null) {
      // Caller is expected to have called _ensureAuthorization first; if
      // not, no-op rather than crashing — sync paths re-check _driveApi.
      return;
    }
    // v3 of extension_google_sign_in_as_googleapis_auth: authClient now
    // hangs off GoogleSignInClientAuthorization and requires the same
    // scopes that were authorized.
    final client = _authorization!.authClient(scopes: _driveScopes);
    _driveApi = drive.DriveApi(client);
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

      // Create backup of current cloud state before overwriting
      await _createCloudBackup(
        folderId,
        docsDir,
        filesToSync,
        actionTitle: 'Pre-Overwrite Cloud Backup',
        tags: ['Safety'],
      );

      final remoteFiles = await _listRemoteFiles(folderId);

      await Future.wait(
        filesToSync.map((fileName) async {
          final localFile = File(p.join(docsDir.path, fileName));
          if (localFile.existsSync()) {
            final remoteFile = remoteFiles[fileName];
            if (remoteFile != null) {
              _log.info('Overwriting remote $fileName...');
              await _updateFile(remoteFile.id!, localFile);
            } else {
              _log.info('Uploading new remote $fileName...');
              await _uploadFile(localFile, fileName, folderId);
            }
          }
        }),
      );
      await _saveLastSyncTime(DateTime.now());
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

      // Create backup of current local state before overwriting
      await _createCloudBackup(
        folderId,
        docsDir,
        filesToSync,
        actionTitle: 'Pre-Overwrite Local Backup',
        tags: ['Safety'],
      );

      final remoteFiles = await _listRemoteFiles(folderId);

      await Future.wait(
        filesToSync.map((fileName) async {
          final remoteFile = remoteFiles[fileName];
          if (remoteFile != null) {
            final localFile = File(p.join(docsDir.path, fileName));
            _log.info('Overwriting local $fileName...');
            await _downloadFile(remoteFile.id!, localFile);
          }
        }),
      );

      await Future.wait([
        if (sessionRepository != null) sessionRepository!.refresh(),
        if (attendanceRepository != null) attendanceRepository!.refresh(),
        if (eventRepository != null) eventRepository!.refresh(),
      ]);
      await _saveLastSyncTime(DateTime.now());
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> syncFiles({
    String actionTitle = 'Manual Sync',
    List<String> tags = const [],
    bool isInitialSetup = false,
  }) async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      await _checkIntegrity();

      if (_driveApi == null) {
        // Try to initialize silently if signed in
        if (_currentUser != null) {
          if (_authorization == null) {
            await _ensureAuthorization(_currentUser!);
          }
          await _initDriveApi();
        } else {
          // Attempt silent sign in
          await signInSilently();
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
      final stats = SyncStats();

      // 2. Process each file
      await Future.wait(
        filesToSync.map((fileName) async {
          final localFile = File(p.join(docsDir.path, fileName));
          final remoteFile = remoteFiles[fileName];

          if (!localFile.existsSync() && remoteFile != null) {
            // Remote exists, local doesn't -> Download
            _log.info('Downloading $fileName...');
            await _downloadFile(remoteFile.id!, localFile);
          } else if (localFile.existsSync() && remoteFile == null) {
            // Local exists, remote doesn't -> Upload
            _log.info('Uploading $fileName...');
            await _uploadFile(localFile, fileName, folderId);
          } else if (localFile.existsSync() && remoteFile != null) {
            // Both exist -> MERGE data
            _log.info('Merging $fileName...');
            await _mergeAndSyncFile(
              remoteFile.id!,
              localFile,
              folderId,
              fileName,
              stats: stats,
            );
          }
        }),
      );

      await _saveLastSyncTime(DateTime.now());
      // Refresh repositories to reflect synced changes in UI
      await Future.wait([
        if (sessionRepository != null) sessionRepository!.refresh(),
        if (attendanceRepository != null) attendanceRepository!.refresh(),
        if (eventRepository != null) eventRepository!.refresh(),
      ]);

      final List<String> combinedTags = [...tags, ...stats.toTags()];

      // 3. Create Cloud Backup snapshot
      await _createCloudBackup(
        folderId,
        docsDir,
        filesToSync,
        actionTitle: actionTitle,
        tags: combinedTags,
        isInitialSetup: isInitialSetup,
      );
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 403 &&
          e.message != null &&
          e.message!.contains('Google Drive API has not been used')) {
        _log.warning('Sync failed: Google Drive API is not enabled.');
        throw Exception(
          'Google Drive API is disabled. Enable it here: '
          'https://console.developers.google.com/apis/api/drive.googleapis.com/overview?project=$yourGoogleProjectNumber',
        );
      }
      _log.error(
        'Sync failed (DetailedApiRequestError ${e.status}: ${e.message})',
        e,
      );
      rethrow;
    } catch (e, st) {
      _log.error('Sync failed', e, st);
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _createCloudBackup(
    String parentId,
    Directory docsDir,
    List<String> filesToBackup, {
    String actionTitle = 'Snapshot',
    List<String> tags = const [],
    bool isInitialSetup = false,
  }) async {
    try {
      final backupFolderId = await _getOrCreateBackupFolder(parentId);

      // Create ZIP
      final encoder = ZipFileEncoder();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupName = 'attendance_snapshot_$timestamp.zip';
      final backupPath = p.join(docsDir.path, backupName);
      encoder.create(backupPath);

      try {
        for (final fileName in filesToBackup) {
          final file = File(p.join(docsDir.path, fileName));
          if (await file.exists()) {
            await encoder.addFile(file);
          }
        }
      } finally {
        await encoder.close();
      }

      // Upload ZIP
      final backupFile = File(backupPath);
      final media = drive.Media(backupFile.openRead(), backupFile.lengthSync());

      final String user = currentUser?.displayName ?? 'System';
      final Map<String, dynamic> metadata = {
        'title': actionTitle,
        'user': user,
        'tags': tags,
        'isInitialSetup': isInitialSetup,
      };

      final driveFile = drive.File()
        ..name = backupName
        ..description = jsonEncode(metadata)
        ..parents = [backupFolderId];

      await _driveApi!.files.create(driveFile, uploadMedia: media);

      // Cleanup local ZIP
      await backupFile.delete();
    } catch (e, st) {
      _log.error('Failed to create cloud backup', e, st);
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
      $fields: 'files(id, name, description, createdTime, size)',
      orderBy: 'createdTime desc',
      pageSize: 1000,
    );

    return fileList.files ?? [];
  }

  Future<void> restoreFromBackup(String fileId, {String? backupDateLabel}) async {
    if (_driveApi == null) return;

    final docsDir = await getApplicationDocumentsDirectory();

    // 1. Download ZIP
    final media =
        await _driveApi!.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final List<int> bytes = [];
    await media.stream.forEach(bytes.addAll);

    // 2. Extract and Merge
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final localFile = File(p.join(docsDir.path, filename));

        if (localFile.existsSync() && filename.endsWith('.json')) {
          try {
            final backupContent = utf8.decode(data);
            final localContent = await localFile.readAsString();

            final backupJson = jsonDecode(backupContent);
            final localJson = jsonDecode(localContent);

            final isHistoryFile = filename == 'sessions_history.json';
            dynamic mergedJson;

            if (isHistoryFile) {
              if (backupJson is Map<String, dynamic> &&
                  localJson is Map<String, dynamic>) {
                mergedJson = _mergeHistoryMaps(localJson, backupJson);
              }
            } else {
              if (backupJson is List && localJson is List) {
                mergedJson = _mergeJsonLists(localJson, backupJson, filename);
              }
            }

            if (mergedJson != null) {
              await localFile.writeAsString(jsonEncode(mergedJson));
            } else {
              // Fallback to overwrite if merge fails or types mismatch
              await localFile.writeAsBytes(data);
            }
          } catch (e, st) {
            _log.warning('Merge failed for $filename during restore', e, st);
            await localFile.writeAsBytes(data);
          }
        } else {
          // New file or non-json (though we only expect json)
          await localFile.create(recursive: true);
          await localFile.writeAsBytes(data);
        }
      }
    }

    // 3. Refresh repositories
    await Future.wait([
      if (sessionRepository != null) sessionRepository!.refresh(),
      if (attendanceRepository != null) attendanceRepository!.refresh(),
      if (eventRepository != null) eventRepository!.refresh(),
    ]);

    // 4. Trigger a full sync to create a NEW version on the cloud
    final label = backupDateLabel ?? 'previous backup';
    await syncFiles(
      actionTitle: 'Restored from $label',
      tags: ['Restore'],
    );

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
    final duplicatesToTrash = <String>[];
    if (fileList.files != null) {
      for (final file in fileList.files!) {
        if (file.name != null) {
          if (!map.containsKey(file.name)) {
            map[file.name!] = file;
          } else {
            // Keep the most recent, trash the older duplicate
            final existing = map[file.name]!;
            if (existing.modifiedTime != null &&
                file.modifiedTime != null &&
                file.modifiedTime!.isAfter(existing.modifiedTime!)) {
              duplicatesToTrash.add(existing.id!);
              map[file.name!] = file;
            } else {
              duplicatesToTrash.add(file.id!);
            }
          }
        }
      }
    }

    // Clean up duplicates in background
    await Future.wait(
      duplicatesToTrash.map((id) async {
        try {
          await _driveApi!.files.update(drive.File()..trashed = true, id);
          _log.info('Trashed duplicate remote file: $id');
        } catch (e, st) {
          _log.warning('Failed to trash duplicate', e, st);
        }
      }),
    );

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
    String fileName, {
    SyncStats? stats,
  }) async {
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
            stats: stats,
          );
        }
        final mergedContent = jsonEncode(mergedJson);

        // 3. Update local (atomic write)
        final tmpFile = File('${localFile.path}.tmp');
        await tmpFile.writeAsString(mergedContent);
        final backupFile = File('${localFile.path}.bak');
        if (await localFile.exists()) {
          if (await backupFile.exists()) {
            await backupFile.delete();
          }
          await localFile.rename(backupFile.path);
        }
        await tmpFile.rename(localFile.path);

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
    } catch (e, st) {
      _log.warning('Sync integrity check failed for $fileName', e, st);
      // HEALING PATH:
      // If remote is corrupted (Format/Decode error), force upload local to "heal" cloud.
      // Only do this if local is healthy.
      try {
        final localCheck = jsonDecode(localContent);
        if (localCheck is List || localCheck is Map) {
          _log.info('Local data is healthy. Healing cloud with local copy.');
          await _updateFile(fileId, localFile);
        }
      } catch (localError, localStack) {
        _log.error(
          'Both local and remote corrupted. Manual restore required.',
          localError,
          localStack,
        );
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

    if (remoteModTime == null) {
      // Remote has no modification time — upload local to be safe
      await _updateFile(fileId, localFile);
    } else if (remoteModTime.isAfter(
      localModTime.add(const Duration(seconds: 5)),
    )) {
      await _downloadFile(fileId, localFile);
    } else if (localModTime.isAfter(
      remoteModTime.add(const Duration(seconds: 5)),
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
      sortedVersions.sort(
        (a, b) => (b['version'] as int).compareTo(a['version'] as int),
      );
      merged[sessionId] = sortedVersions;
    }

    return merged;
  }

  List<dynamic> _mergeJsonLists(
    List<dynamic> local,
    List<dynamic> remote,
    String fileName, {
    SyncStats? stats,
  }) {
    final Map<String, dynamic> merged = {};

    void process(List<dynamic> list, {bool isRemote = false}) {
      for (final item in list) {
        if (item is Map && item.containsKey('id')) {
          final id = item['id'] as String;
          if (!merged.containsKey(id)) {
            merged[id] = item;
            if (isRemote && stats != null) {
              if (fileName == 'sessions.json') stats.newSessions++;
              if (fileName == 'events.json') stats.newEvents++;
              if (fileName == 'families.json') stats.newFamilies++;
              if (fileName == 'members') stats.newMembers++;
            }
          } else {
            // Tie-break: Use updatedAt if available
            final existing = merged[id] as Map;
            final current = item;

            final currentUpdatedAt = current.containsKey('updatedAt')
                ? DateTime.tryParse(current['updatedAt'])
                : null;
            final existingUpdatedAt = existing.containsKey('updatedAt')
                ? DateTime.tryParse(existing['updatedAt'])
                : null;

            if (currentUpdatedAt != null && existingUpdatedAt != null) {
              if (currentUpdatedAt.isAfter(existingUpdatedAt)) {
                merged[id] = item;
              }
              // If same timestamp, keep existing (first-wins)
            } else if (fileName == 'families.json') {
              // Legacy families without updatedAt: merge member lists
              final mergedMembers = _mergeJsonLists(
                existing['members'] as List? ?? [],
                current['members'] as List? ?? [],
                'members',
                stats: stats,
              );
              merged[id] = {...existing, 'members': mergedMembers};
            }
          }
        }
      }
    }

    process(local);
    process(remote, isRemote: true);

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
  // ignore: use_setters_to_change_properties
  void debugSetDriveApi(drive.DriveApi api) {
    _driveApi = api;
  }

  @visibleForTesting
  List<dynamic> testMergeJsonLists(
    List<dynamic> local,
    List<dynamic> remote,
    String fileName, {
    SyncStats? stats,
  }) {
    return _mergeJsonLists(local, remote, fileName, stats: stats);
  }

  @visibleForTesting
  Map<String, dynamic> testMergeHistoryMaps(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    return _mergeHistoryMaps(local, remote);
  }
}
