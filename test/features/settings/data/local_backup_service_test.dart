import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:attendance_tracker/features/settings/data/local_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

void main() {
  late Directory tempDir;
  late List<XFile> sharedFiles;
  late String? sharedText;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('local_backup_service_');
    sharedFiles = [];
    sharedText = null;
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  LocalBackupService service() {
    return LocalBackupService(
      documentsDirectoryProvider: () async => tempDir,
      shareFiles: (files, {text}) async {
        sharedFiles = files;
        sharedText = text;
        return const ShareResult('success', ShareResultStatus.success);
      },
    );
  }

  LocalBackupService serviceWithShareText(LocalBackupShareText shareText) {
    return LocalBackupService(
      documentsDirectoryProvider: () async => tempDir,
      shareText: shareText,
      shareFiles: (files, {text}) async {
        sharedFiles = files;
        sharedText = text;
        return const ShareResult('success', ShareResultStatus.success);
      },
    );
  }

  test('createBackup zips existing local data files and shares the zip',
      () async {
    await File(p.join(tempDir.path, 'sessions.json')).writeAsString('[]');
    await File(p.join(tempDir.path, 'families.json')).writeAsString('[]');

    await service().createBackup();

    expect(sharedText, 'Attendance Tracker Backup');
    expect(sharedFiles, hasLength(1));
    expect(p.basename(sharedFiles.single.path), 'attendance_backup.zip');

    final bytes = await File(sharedFiles.single.path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.files.map((file) => file.name), contains('sessions.json'));
    expect(archive.files.map((file) => file.name), contains('families.json'));
  });

  test('createBackup uses injected share text', () async {
    await File(p.join(tempDir.path, 'sessions.json')).writeAsString('[]');

    await serviceWithShareText(
      const LocalBackupShareText(backup: 'Localized backup'),
    ).createBackup();

    expect(sharedText, 'Localized backup');
  });
}
