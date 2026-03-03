import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class GoogleSheetsService {
  Future<void> syncAttendance(String webAppUrl) async {
    if (webAppUrl.trim().isEmpty) return;

    try {
      final payload = await _buildPayload();
      if (payload == null) return;

      final response = await http.post(
        Uri.parse(webAppUrl),
        body: jsonEncode(payload),
        headers: {'Content-Type': 'text/plain'}, // Avoids CORS preflight
      );

      print(
        'Google Sheets sync response: ${response.statusCode} ${response.body}',
      );
    } catch (e) {
      print('Google Sheets sync failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _buildPayload() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final sessionsFile = File(p.join(docsDir.path, 'sessions.json'));
    final familiesFile = File(p.join(docsDir.path, 'families.json'));

    if (!await sessionsFile.exists()) {
      return null;
    }

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
        print('Error loading families for Google Sheets sync: $e');
      }
    }

    final content = await sessionsFile.readAsString();
    final List<dynamic> sessionsJson = jsonDecode(content);

    final dateFormat = DateFormat('yyyy-MM-dd');

    final List<Map<String, dynamic>> records = [];

    for (final s in sessionsJson) {
      final date = DateTime.parse(s['sessionDate']);
      final dateStr = dateFormat.format(date);
      final title = s['title'];
      final sessionRecords = s['records'] as List<dynamic>?;

      if (sessionRecords != null) {
        for (final r in sessionRecords) {
          final memberId = r['attendee'];
          final memberName = memberNames[memberId] ?? memberId;
          final status = r['status'];

          records.add({
            'name': '[$dateStr] $title - $memberName',
            'status': status,
          });
        }
      }
    }

    if (records.isEmpty) {
      return null;
    }

    final syncDate = DateTime.now();

    return {'date': syncDate.toIso8601String(), 'records': records};
  }
}
