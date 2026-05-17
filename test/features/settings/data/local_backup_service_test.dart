import 'dart:convert';
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

  test('exportData throws when there is no session data', () async {
    await expectLater(
      service().exportData(),
      throwsA(isA<Exception>()),
    );

    expect(sharedFiles, isEmpty);
  });

  test('exportData writes escaped CSV and shares it', () async {
    final sessions = [
      {
        'id': 'session-1',
        'title': 'Morning, "Check"\nIn',
        'sessionDate': '2024-01-09T10:00:00.000',
        'records': [
          {
            'attendee': 'member-1',
            'status': 'present, "checked"\nin',
            'recordedAt': '2024-01-09T10:15:30.000',
          },
          {
            'attendee': 'Unknown, Guest',
            'status': 'absent',
            'recordedAt': '2024-01-09T10:16:30.000',
          },
        ],
      },
    ];
    final families = [
      {
        'id': 'family-1',
        'displayName': 'Smith Family',
        'members': [
          {
            'id': 'member-1',
            'displayName': 'Alice, "Ace"\nSmith',
          },
        ],
      },
    ];

    await File(
      p.join(tempDir.path, 'sessions.json'),
    ).writeAsString(jsonEncode(sessions));
    await File(
      p.join(tempDir.path, 'families.json'),
    ).writeAsString(jsonEncode(families));

    await service().exportData();

    expect(sharedText, 'Attendance Data Export (CSV)');
    expect(sharedFiles, hasLength(1));
    expect(p.basename(sharedFiles.single.path), 'attendance_export.csv');

    final csv = await File(sharedFiles.single.path).readAsString();
    expect(
      csv,
      contains(
        'Date,Session Title,Member Name,Status,Recorded At\n'
        '2024-01-09,"Morning, ""Check""\n'
        'In","Alice, ""Ace""\n'
        'Smith","present, ""checked""\n'
        'in",2024-01-09 10:15:30\n',
      ),
    );
    expect(
      csv,
      contains(
        '2024-01-09,"Morning, ""Check""\n'
        'In","Unknown, Guest",absent,2024-01-09 10:16:30\n',
      ),
    );
  });

  test('exportData uses injected share text', () async {
    await File(p.join(tempDir.path, 'sessions.json')).writeAsString('[]');

    await serviceWithShareText(
      const LocalBackupShareText(exportCsv: 'Localized CSV export'),
    ).exportData();

    expect(sharedText, 'Localized CSV export');
  });
}
