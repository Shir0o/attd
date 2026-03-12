import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LocalBackupService {
  Future<void> createBackup() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final filesToBackup = [
        'sessions.json',
        'families.json',
        'events.json',
        'sessions_history.json',
      ];

      final encoder = ZipFileEncoder();
      final backupPath = p.join(docsDir.path, 'attendance_backup.zip');
      encoder.create(backupPath);

      for (final fileName in filesToBackup) {
        final file = File(p.join(docsDir.path, fileName));
        if (await file.exists()) {
          encoder.addFile(file);
        }
      }

      encoder.close();

      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        final result = await Share.shareXFiles([
          XFile(backupPath),
        ], text: 'Attendance Tracker Backup');

        if (result.status == ShareResultStatus.success) {
          print('Backup shared successfully');
        }
      } else {
        throw Exception('Backup file creation failed');
      }
    } catch (e) {
      print('Backup failed: $e');
      rethrow;
    }
  }

  Future<void> exportData() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final sessionsFile = File(p.join(docsDir.path, 'sessions.json'));
      final familiesFile = File(p.join(docsDir.path, 'families.json'));

      if (!await sessionsFile.exists()) {
        throw Exception('No session data found to export');
      }

      // Load families for name resolution
      final Map<String, String> memberNames = {};
      if (await familiesFile.exists()) {
        try {
          final content = await familiesFile.readAsString();
          final List<dynamic> familiesJson = jsonDecode(content);
          for (final f in familiesJson) {
            final members = f['members'] as List<dynamic>?;
            if (members != null) {
              for (final m in members) {
                memberNames[m['id']] = m['displayName'];
              }
            }
          }
        } catch (e) {
          print('Error loading families for export: $e');
        }
      }

      // Load sessions
      final content = await sessionsFile.readAsString();
      final List<dynamic> sessionsJson = jsonDecode(content);

      // Create CSV content
      final buffer = StringBuffer();
      buffer.writeln('Date,Session Title,Member Name,Status,Recorded At');

      final dateFormat = DateFormat('yyyy-MM-dd');
      final timeFormat = DateFormat('HH:mm:ss');

      for (final s in sessionsJson) {
        final date = DateTime.parse(s['sessionDate']);
        final dateStr = dateFormat.format(date);
        final title = _escapeCsv(s['title']);
        final records = s['records'] as List<dynamic>?;

        if (records != null) {
          for (final r in records) {
            final memberId = r['attendee'];
            final memberName = _escapeCsv(memberNames[memberId] ?? memberId);
            final status = r['status'];
            final recordedAt = DateTime.parse(r['recordedAt']);
            final recordedAtStr =
                '${dateFormat.format(recordedAt)} ${timeFormat.format(recordedAt)}';

            buffer.writeln(
              '$dateStr,$title,$memberName,$status,$recordedAtStr',
            );
          }
        }
      }

      final csvPath = p.join(docsDir.path, 'attendance_export.csv');
      final csvFile = File(csvPath);
      await csvFile.writeAsString(buffer.toString());

      await Share.shareXFiles([
        XFile(csvPath),
      ], text: 'Attendance Data Export (CSV)');
    } catch (e) {
      print('Export failed: $e');
      rethrow;
    }
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
