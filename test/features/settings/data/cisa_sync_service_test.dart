import 'dart:convert';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/settings/data/cisa_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CisaSyncService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('buildPayload formats recurrence metadata, sessionDate and records properly', () {
      final service = CisaSyncService();
      final event = Event(
        id: 'event-uuid-1',
        title: 'Wednesday Bible Study',
        time: const TimeOfDay(hour: 19, minute: 0),
        frequency: 'Weekly',
        repeatingDays: ['Wednesday'],
        createdAt: DateTime.parse('2026-09-01T00:00:00.000Z'),
      );

      final session = Session(
        id: 'session-uuid-1',
        eventId: 'event-uuid-1',
        title: 'Wednesday Bible Study',
        sessionDate: DateTime.parse('2026-09-16T19:00:00.000Z'),
        createdAt: DateTime.parse('2026-09-16T19:00:00.000Z'),
        updatedAt: DateTime.parse('2026-09-16T20:00:00.000Z'),
        createdBy: 'User',
        records: [
          SessionRecord(
            memberId: 'member-uuid-1',
            attendee: 'Alex Chen',
            status: AttendanceStatus.present,
            recordedAt: DateTime.parse('2026-09-16T19:15:00.000Z'),
            recordedBy: 'User',
            isLate: false,
          ),
          SessionRecord(
            memberId: 'member-uuid-2',
            attendee: 'Jordan Lee',
            status: AttendanceStatus.present,
            recordedAt: DateTime.parse('2026-09-16T19:25:00.000Z'),
            recordedBy: 'User',
            isLate: true,
          ),
          SessionRecord(
            memberId: null,
            attendee: 'Sam Guest',
            status: AttendanceStatus.absent,
            recordedAt: DateTime.parse('2026-09-16T19:10:00.000Z'),
            recordedBy: 'User',
            isLate: false,
          ),
        ],
      );

      final payload = service.buildPayload(session: session, event: event);

      expect(payload['attdEventId'], 'event-uuid-1');
      expect(payload['eventName'], 'Wednesday Bible Study');
      expect(payload['frequency'], 'Weekly');
      expect(payload['repeatingDays'], ['Wednesday']);
      expect(payload['eventTime'], '19:00');
      expect(payload['sessionDate'], '2026-09-16');

      final records = payload['records'] as List<dynamic>;
      expect(records.length, 3);
      expect(records[0], {
        'memberId': 'member-uuid-1',
        'attendee': 'Alex Chen',
        'status': 'present',
        'isLate': false,
        'recordedAt': '2026-09-16T19:15:00.000Z',
      });
      expect(records[1], {
        'memberId': 'member-uuid-2',
        'attendee': 'Jordan Lee',
        'status': 'late',
        'isLate': true,
        'recordedAt': '2026-09-16T19:25:00.000Z',
      });
      expect(records[2], {
        'memberId': null,
        'attendee': 'Sam Guest',
        'status': 'absent',
        'isLate': false,
        'recordedAt': '2026-09-16T19:10:00.000Z',
      });
    });

    test('buildPayload handles standalone session with no event', () {
      final service = CisaSyncService();
      final session = Session(
        id: 'session-uuid-2',
        title: 'Ad-hoc Gathering',
        sessionDate: DateTime.parse('2026-09-20T10:30:00.000Z'),
        createdAt: DateTime.parse('2026-09-20T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-09-20T11:00:00.000Z'),
        createdBy: 'User',
        records: [],
      );

      final payload = service.buildPayload(session: session, event: null);

      expect(payload['attdEventId'], 'session-uuid-2');
      expect(payload['eventName'], 'Ad-hoc Gathering');
      expect(payload['frequency'], 'One-time');
      expect(payload['repeatingDays'], isEmpty);
      expect(payload['eventTime'], '10:30');
      expect(payload['sessionDate'], '2026-09-20');
      expect(payload['records'], isEmpty);
    });

    test('syncSession returns unconfigured when URL or token is missing', () async {
      final service = CisaSyncService();
      final session = Session(
        id: 's1',
        title: 'Gathering',
        sessionDate: DateTime(2026, 9, 21),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'User',
        records: [],
      );

      final resultMissingAll = await service.syncSession(session: session);
      expect(resultMissingAll.isConfigured, isFalse);
      expect(resultMissingAll.success, isFalse);
      expect(resultMissingAll.errorMessage, contains('configured'));

      await service.saveConfig(cisaSyncUrl: 'https://cisa.tracker.org/intake', cisaSyncToken: '');
      final resultMissingToken = await service.syncSession(session: session);
      expect(resultMissingToken.isConfigured, isFalse);
      expect(resultMissingToken.success, isFalse);
    });

    test('syncSession sends POST request with headers and payload on 200/201 response', () async {
      await CisaSyncService().saveConfig(
        cisaSyncUrl: 'https://cisa.tracker.org/intake',
        cisaSyncToken: 'secret-token-123',
      );

      http.Request? capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'status': 'ok', 'synced': 1}), 200);
      });

      final service = CisaSyncService(client: client);
      final session = Session(
        id: 's1',
        eventId: 'e1',
        title: 'Gathering',
        sessionDate: DateTime.parse('2026-09-21T18:00:00.000Z'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'User',
        records: [
          SessionRecord(
            memberId: 'm1',
            attendee: 'Test User',
            status: AttendanceStatus.present,
            recordedAt: DateTime.parse('2026-09-21T18:05:00.000Z'),
            recordedBy: 'User',
            isLate: false,
          ),
        ],
      );

      final result = await service.syncSession(session: session);
      expect(result.isConfigured, isTrue);
      expect(result.success, isTrue);
      expect(result.statusCode, 200);

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.url.toString(), 'https://cisa.tracker.org/intake');
      expect(capturedRequest!.method, 'POST');
      expect(capturedRequest!.headers['x-sync-token'], 'secret-token-123');
      expect(capturedRequest!.headers['content-type'], contains('application/json'));

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['eventName'], 'Gathering');
      expect((body['records'] as List).length, 1);
    });

    test('syncSession handles 401 unauthorized status cleanly', () async {
      await CisaSyncService().saveConfig(
        cisaSyncUrl: 'https://cisa.tracker.org/intake',
        cisaSyncToken: 'bad-token',
      );

      final client = MockClient((request) async {
        return http.Response('Invalid sync token', 401);
      });

      final service = CisaSyncService(client: client);
      final session = Session(
        id: 's1',
        title: 'Gathering',
        sessionDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'User',
        records: [],
      );

      final result = await service.syncSession(session: session);
      expect(result.isConfigured, isTrue);
      expect(result.success, isFalse);
      expect(result.statusCode, 401);
      expect(result.errorMessage, contains('Unauthorized'));
    });

    test('syncSession handles server 500 error cleanly', () async {
      await CisaSyncService().saveConfig(
        cisaSyncUrl: 'https://cisa.tracker.org/intake',
        cisaSyncToken: 'token',
      );

      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = CisaSyncService(client: client);
      final session = Session(
        id: 's1',
        title: 'Gathering',
        sessionDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'User',
        records: [],
      );

      final result = await service.syncSession(session: session);
      expect(result.isConfigured, isTrue);
      expect(result.success, isFalse);
      expect(result.statusCode, 500);
      expect(result.errorMessage, contains('Server error'));
    });

    test('syncSession is safe offline and catches network socket exceptions', () async {
      await CisaSyncService().saveConfig(
        cisaSyncUrl: 'https://cisa.tracker.org/intake',
        cisaSyncToken: 'token',
      );

      final client = MockClient((request) async {
        throw http.ClientException('Failed to connect to host');
      });

      final service = CisaSyncService(client: client);
      final session = Session(
        id: 's1',
        title: 'Gathering',
        sessionDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'User',
        records: [],
      );

      final result = await service.syncSession(session: session);
      expect(result.isConfigured, isTrue);
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('network failure'));
    });
  });
}
