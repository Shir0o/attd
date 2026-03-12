import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

class GoogleSheetsService {
  static const String _lastSheetsSyncKey = 'last_sheets_sync_time';

  Future<void> syncAttendance(String webAppUrl) async {
    if (webAppUrl.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString(_lastSheetsSyncKey);
      final lastSync = lastSyncStr != null
          ? DateTime.parse(lastSyncStr)
          : DateTime.fromMillisecondsSinceEpoch(0);

      final payload = await _buildPayload(lastSync);
      if (payload == null) {
        print('No new records to sync to Google Sheets');
        return;
      }

      final response = await http.post(
        Uri.parse(webAppUrl),
        body: jsonEncode(payload),
        headers: {'Content-Type': 'text/plain'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await prefs.setString(
          _lastSheetsSyncKey,
          DateTime.now().toIso8601String(),
        );
      }

      print(
        'Google Sheets sync response: ${response.statusCode} ${response.body}',
      );
    } catch (e) {
      print('Google Sheets sync failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _buildPayload(DateTime since) async {
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
      final updatedAtStr = s['updatedAt'];
      if (updatedAtStr == null) continue;

      final updatedAt = DateTime.parse(updatedAtStr);
      // We sync if the session was UPDATED since the last sync.
      // This includes newly added historical sessions (since their updatedAt will be 'now').
      if (!updatedAt.isAfter(since)) continue;

      final sessionDateStr = s['sessionDate'];
      if (sessionDateStr == null) continue;

      final sessionDate = DateTime.parse(sessionDateStr);
      final dateStr = dateFormat.format(sessionDate);
      final title = s['title'] ?? 'Untitled';
      final sessionRecords = s['records'] as List<dynamic>?;

      if (sessionRecords != null) {
        for (final r in sessionRecords) {
          // The attendee field already contains the displayName (not the ID),
          // as per SessionRecord.toJson and its usage in the deck/summary pages.
          final attendeeName = r['attendee'] as String? ?? 'Unknown';
          final status = r['status'] as String? ?? 'absent';

          records.add({
            'name': '[$dateStr] $title - $attendeeName',
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
