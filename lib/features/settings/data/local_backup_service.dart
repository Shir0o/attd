import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/logging/app_logger.dart';

final _log = AppLogger('LocalBackup');

typedef DocumentsDirectoryProvider = Future<Directory> Function();
typedef ShareFiles = Future<ShareResult> Function(
  List<XFile> files, {
  String? text,
});

class LocalBackupShareText {
  const LocalBackupShareText({
    this.backup = 'Attendance Tracker Backup',
  });

  final String backup;
}

class LocalBackupService {
  LocalBackupService({
    DocumentsDirectoryProvider? documentsDirectoryProvider,
    ShareFiles? shareFiles,
    LocalBackupShareText shareText = const LocalBackupShareText(),
  })  : _documentsDirectoryProvider =
            documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
        _shareFiles = shareFiles ??
            ((files, {text}) => Share.shareXFiles(files, text: text)),
        _shareText = shareText;

  final DocumentsDirectoryProvider _documentsDirectoryProvider;
  final ShareFiles _shareFiles;
  final LocalBackupShareText _shareText;

  Future<void> createBackup() async {
    try {
      final docsDir = await _documentsDirectoryProvider();
      final filesToBackup = [
        'sessions.json',
        'families.json',
        'events.json',
        'sessions_history.json',
      ];

      final encoder = ZipFileEncoder();
      final backupPath = p.join(docsDir.path, 'attendance_backup.zip');
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

      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        final result = await _shareFiles(
          [XFile(backupPath)],
          text: _shareText.backup,
        );

        if (result.status == ShareResultStatus.success) {
          _log.info('Backup shared successfully');
        }
      } else {
        throw Exception('Backup file creation failed');
      }
    } catch (e, st) {
      _log.error('Backup failed', e, st);
      rethrow;
    }
  }
}
