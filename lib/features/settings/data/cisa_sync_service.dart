import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/app_logger.dart';
import '../../../data/session.dart';
import '../../hub/domain/event.dart';

final _log = AppLogger('CisaSync');

class CisaSyncConfig {
  const CisaSyncConfig({
    required this.cisaSyncUrl,
    required this.cisaSyncToken,
  });

  final String cisaSyncUrl;
  final String cisaSyncToken;

  bool get isConfigured =>
      cisaSyncUrl.trim().isNotEmpty && cisaSyncToken.trim().isNotEmpty;
}

class CisaSyncResult {
  const CisaSyncResult({
    required this.success,
    required this.isConfigured,
    this.statusCode,
    this.errorMessage,
  });

  final bool success;
  final bool isConfigured;
  final int? statusCode;
  final String? errorMessage;
}

class CisaSyncService {
  CisaSyncService({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  static const String keyCisaSyncUrl = 'cisa_sync_url';
  static const String keyCisaSyncToken = 'cisa_sync_token';

  Future<CisaSyncConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return CisaSyncConfig(
      cisaSyncUrl: prefs.getString(keyCisaSyncUrl) ?? '',
      cisaSyncToken: prefs.getString(keyCisaSyncToken) ?? '',
    );
  }

  Future<void> saveConfig({
    required String cisaSyncUrl,
    required String cisaSyncToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyCisaSyncUrl, cisaSyncUrl.trim());
    await prefs.setString(keyCisaSyncToken, cisaSyncToken.trim());
  }

  Map<String, dynamic> buildPayload({
    required Session session,
    Event? event,
  }) {
    final attdEventId = event?.id ?? session.eventId ?? session.id;
    final eventName = session.title;
    final frequency = event?.frequency ?? 'One-time';
    final repeatingDays = event?.repeatingDays ?? const <String>[];

    String eventTime;
    if (event != null) {
      final hourStr = event.time.hour.toString().padLeft(2, '0');
      final minStr = event.time.minute.toString().padLeft(2, '0');
      eventTime = '$hourStr:$minStr';
    } else {
      final hourStr = session.sessionDate.hour.toString().padLeft(2, '0');
      final minStr = session.sessionDate.minute.toString().padLeft(2, '0');
      eventTime = '$hourStr:$minStr';
    }

    final sessionDate = DateFormat('yyyy-MM-dd').format(session.sessionDate);

    final records = session.records.map((r) {
      final statusStr = r.isLate ? 'late' : r.status.name;
      return {
        'memberId': r.memberId,
        'attendee': r.attendee,
        'status': statusStr,
        'isLate': r.isLate,
        'recordedAt': r.recordedAt.toIso8601String(),
      };
    }).toList();

    return {
      'attdEventId': attdEventId,
      'eventName': eventName,
      'frequency': frequency,
      'repeatingDays': repeatingDays,
      'eventTime': eventTime,
      'sessionDate': sessionDate,
      'records': records,
    };
  }

  Future<CisaSyncResult> syncSession({
    required Session session,
    Event? event,
  }) async {
    final config = await loadConfig();
    if (!config.isConfigured) {
      return const CisaSyncResult(
        success: false,
        isConfigured: false,
        errorMessage: 'CISA Sync URL and Token must be configured in Settings.',
      );
    }

    try {
      final payload = buildPayload(session: session, event: event);
      final response = await _client.post(
        Uri.parse(config.cisaSyncUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-sync-token': config.cisaSyncToken,
        },
        body: jsonEncode(payload),
      );

      _log.info('CISA Sync response: ${response.statusCode} ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return CisaSyncResult(
          success: true,
          isConfigured: true,
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 401) {
        return CisaSyncResult(
          success: false,
          isConfigured: true,
          statusCode: response.statusCode,
          errorMessage: 'Unauthorized: Invalid CISA Sync Token.',
        );
      } else {
        return CisaSyncResult(
          success: false,
          isConfigured: true,
          statusCode: response.statusCode,
          errorMessage: 'Server error (${response.statusCode}): ${response.body.isNotEmpty ? response.body : "Request failed."}',
        );
      }
    } catch (e, st) {
      _log.warning('CISA Sync network or client failure', e, st);
      return CisaSyncResult(
        success: false,
        isConfigured: true,
        errorMessage: 'Sync failed due to a network failure: $e',
      );
    }
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
