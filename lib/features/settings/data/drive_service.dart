import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DriveService extends ChangeNotifier {
  DriveService({required GoogleSignIn googleSignIn})
      : _googleSignIn = googleSignIn;

  final GoogleSignIn _googleSignIn;
  drive.DriveApi? _driveApi;
  DateTime? _lastSyncTime;
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<void> signIn() async {
    try {
      await _googleSignIn.signIn();
      await _initDriveApi();
      notifyListeners();
    } catch (e) {
      print('Sign in failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _driveApi = null;
    notifyListeners();
  }

  Future<void> _initDriveApi() async {
    if (_driveApi != null) return;
    final client = await _googleSignIn.authenticatedClient();
    if (client != null) {
      _driveApi = drive.DriveApi(client);
    }
  }

  Future<void> syncFiles() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
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

      final docsDir = await getApplicationDocumentsDirectory();
      final filesToSync = [
        'sessions.json',
        'families.json',
        'events.json',
        'sessions_history.json',
      ];

      // 1. Get remote files
      final remoteFiles = await _listRemoteFiles();

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
          await _uploadFile(localFile, fileName);
        } else if (localFile.existsSync() && remoteFile != null) {
          // Both exist -> Compare modification times
          // Note: Drive 'modifiedTime' is UTC. Local 'lastModified' is local.
          final localModTime = await localFile.lastModified();
          final remoteModTime = remoteFile.modifiedTime;

          if (remoteModTime != null && remoteModTime.isAfter(localModTime.add(const Duration(seconds: 5)))) {
             // Remote is newer (allowing 5s buffer) -> Download
             print('Downloading newer $fileName...');
             await _downloadFile(remoteFile.id!, localFile);
          } else if (localModTime.isAfter(remoteModTime!.add(const Duration(seconds: 5)))) {
            // Local is newer -> Update remote
            print('Updating remote $fileName...');
            await _updateFile(remoteFile.id!, localFile);
          } else {
            print('$fileName is in sync.');
          }
        }
      }

      _lastSyncTime = DateTime.now();
      // TODO: Persist last sync time
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 403 && e.message != null && e.message!.contains('Google Drive API has not been used')) {
        print('Sync failed: Google Drive API is not enabled.');
        throw Exception(
          'Google Drive API is disabled. Enable it here: '
          'https://console.developers.google.com/apis/api/drive.googleapis.com/overview?project=YOUR_GOOGLE_PROJECT_NUMBER'
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

  Future<Map<String, drive.File>> _listRemoteFiles() async {
    final query = "trashed = false and mimeType != 'application/vnd.google-apps.folder'";
    final fileList = await _driveApi!.files.list(q: query, $fields: 'files(id, name, modifiedTime)');

    final map = <String, drive.File>{};
    if (fileList.files != null) {
      for (final file in fileList.files!) {
        if (file.name != null) {
          // Handle duplicates? Just take the first one or latest.
          // drive.file scope limits visibility, so we might not see duplicates from other apps.
          // But if we uploaded multiple times, we might have duplicates.
          // Let's assume we handle duplicates by taking the most recent one.
          if (!map.containsKey(file.name) || map[file.name]!.modifiedTime!.isBefore(file.modifiedTime!)) {
             map[file.name!] = file;
          }
        }
      }
    }
    return map;
  }

  Future<void> _uploadFile(File localFile, String name) async {
    final media = drive.Media(localFile.openRead(), localFile.lengthSync());
    final driveFile = drive.File()..name = name;

    await _driveApi!.files.create(
      driveFile,
      uploadMedia: media,
    );
  }

  Future<void> _updateFile(String fileId, File localFile) async {
    final media = drive.Media(localFile.openRead(), localFile.lengthSync());
    // update modifiedTime explicitly? Drive updates it automatically.
    await _driveApi!.files.update(
      drive.File(),
      fileId,
      uploadMedia: media,
    );
  }

  Future<void> _downloadFile(String fileId, File localFile) async {
    final media = await _driveApi!.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final List<int> dataStore = [];
    await media.stream.forEach((data) {
      dataStore.addAll(data);
    });

    await localFile.writeAsBytes(dataStore);

    // Update local modified time to match remote?
    // Or just leave it as 'now' which means local becomes newer immediately?
    // If we leave it as 'now', next sync will think local is newer and upload it back.
    // This is a common issue.
    // Ideally we set local modified time to remote modified time.
    // Dart File API setLastModified is available.

    final remoteFile = await _driveApi!.files.get(fileId, $fields: 'modifiedTime') as drive.File;
    if (remoteFile.modifiedTime != null) {
      await localFile.setLastModified(remoteFile.modifiedTime!);
    }
  }
}
