import 'dart:convert';
import 'dart:io';

import 'package:attendance_tracker/features/settings/data/google_sheets_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoogleSheetsService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('google_sheets_test');
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns early for a blank Apps Script URL', () async {
      await GoogleSheetsService().syncAttendance('  ');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_sheets_sync_time'), isNull);
    });

    test('returns without posting when there are no local sessions', () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        return http.Response('', HttpStatus.ok);
      });

      await GoogleSheetsService(client: client).syncAttendance(
        'https://script.google.test/sync',
      );

      expect(requestCount, 0);
    });

    test('posts changed attendance records and stores sync time', () async {
      final sessionsFile = File(p.join(tempDir.path, 'sessions.json'));
      await File(p.join(tempDir.path, 'families.json')).writeAsString(
        jsonEncode([
          {
            'id': 'family-1',
            'members': [
              {'id': 'member-1', 'displayName': 'Alex'},
            ],
          },
        ]),
      );
      await sessionsFile.writeAsString(
        jsonEncode([
          {
            'title': 'Sunday Service',
            'sessionDate': '2026-05-17T09:00:00.000',
            'updatedAt': '2026-05-17T10:00:00.000',
            'records': [
              {'attendee': 'Alex', 'status': 'present'},
              {'attendee': 'Jordan', 'status': 'absent'},
            ],
          },
          {
            'title': 'Old Session',
            'sessionDate': '2026-05-10T09:00:00.000',
            'updatedAt': '2026-05-10T10:00:00.000',
            'records': [
              {'attendee': 'Taylor', 'status': 'present'},
            ],
          },
        ]),
      );
      SharedPreferences.setMockInitialValues({
        'last_sheets_sync_time': '2026-05-16T00:00:00.000',
      });

      final receivedBodies = <String>[];
      final client = MockClient((request) async {
        receivedBodies.add(request.body);
        return http.Response('', HttpStatus.ok);
      });

      await GoogleSheetsService(client: client).syncAttendance(
        'https://script.google.test/sync',
      );

      expect(receivedBodies, hasLength(1));
      final payload = jsonDecode(receivedBodies.single) as Map<String, dynamic>;
      final records = payload['records'] as List<dynamic>;
      expect(records, hasLength(2));
      expect(records.first, {
        'name': '[2026-05-17] Sunday Service - Alex',
        'status': 'present',
      });
      expect(
        records.map((record) => record['name']),
        isNot(contains('[2026-05-10] Old Session - Taylor')),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_sheets_sync_time'), isNotNull);
    });

    test('skips sessions without updatedAt or sessionDate', () async {
      final sessionsFile = File(p.join(tempDir.path, 'sessions.json'));
      await sessionsFile.writeAsString(
        jsonEncode([
          {
            'title': 'Missing Updated At',
            'sessionDate': '2026-05-17T09:00:00.000',
            'records': [
              {'attendee': 'Alex', 'status': 'present'},
            ],
          },
          {
            'title': 'Missing Date',
            'updatedAt': '2026-05-17T10:00:00.000',
            'records': [
              {'attendee': 'Jordan', 'status': 'absent'},
            ],
          },
        ]),
      );
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        return http.Response('', HttpStatus.ok);
      });

      await GoogleSheetsService(client: client).syncAttendance(
        'https://script.google.test/sync',
      );

      expect(requestCount, 0);
    });

    test('uses fallback title, attendee, and status values', () async {
      await File(p.join(tempDir.path, 'sessions.json')).writeAsString(
        jsonEncode([
          {
            'sessionDate': '2026-05-17T09:00:00.000',
            'updatedAt': '2026-05-17T10:00:00.000',
            'records': [{}],
          },
        ]),
      );
      await File(p.join(tempDir.path, 'families.json')).writeAsString(
        '{not json',
      );

      final receivedBodies = <String>[];
      final client = MockClient((request) async {
        receivedBodies.add(request.body);
        return http.Response('', HttpStatus.ok);
      });

      await GoogleSheetsService(client: client).syncAttendance(
        'https://script.google.test/sync',
      );

      final payload = jsonDecode(receivedBodies.single) as Map<String, dynamic>;
      expect((payload['records'] as List).single, {
        'name': '[2026-05-17] Untitled - Unknown',
        'status': 'absent',
      });
    });

    test('does not store sync time when server returns an error', () async {
      await File(p.join(tempDir.path, 'sessions.json')).writeAsString(
        jsonEncode([
          {
            'title': 'Sunday Service',
            'sessionDate': '2026-05-17T09:00:00.000',
            'updatedAt': '2026-05-17T10:00:00.000',
            'records': [
              {'attendee': 'Alex', 'status': 'present'},
            ],
          },
        ]),
      );
      final client = MockClient((request) async {
        return http.Response('bad', HttpStatus.internalServerError);
      });

      await GoogleSheetsService(client: client).syncAttendance(
        'https://script.google.test/sync',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_sheets_sync_time'), isNull);
    });

    test('rethrows client errors', () async {
      await File(p.join(tempDir.path, 'sessions.json')).writeAsString(
        jsonEncode([
          {
            'title': 'Sunday Service',
            'sessionDate': '2026-05-17T09:00:00.000',
            'updatedAt': '2026-05-17T10:00:00.000',
            'records': [
              {'attendee': 'Alex', 'status': 'present'},
            ],
          },
        ]),
      );
      final client = MockClient((request) async {
        throw const SocketException('offline');
      });

      await expectLater(
        GoogleSheetsService(client: client).syncAttendance(
          'https://script.google.test/sync',
        ),
        throwsA(isA<SocketException>()),
      );
    });
  });
}
