import 'dart:io';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/reports/report_export_service.dart';
import 'package:attendance_tracker/features/reports/report_models.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

class _FakeSessionRepository extends SessionRepository {
  _FakeSessionRepository(this.sessions);

  final List<Session> sessions;

  @override
  Stream<List<Session>> streamSessions() {
    return Stream.value(sessions);
  }

  @override
  Future<Session> createSession({
    required String title,
    String? eventId,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async =>
      throw UnimplementedError();

  @override
  Future<List<Session>> loadSessions() async => sessions;

  @override
  Future<Session?> findSessionById(String id) async {
    try {
      return sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Session> saveSnapshot(
    Session session, {
    required String actor,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {}

  @override
  Future<List<SessionVersion>> history(String sessionId) async => [];

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2024, 1, 10);
  final sessions = [
    Session(
      id: '1',
      title: 'Morning Standup',
      sessionDate: DateTime(2024, 1, 9),
      records: [
        SessionRecord(
          memberId: 'm1',
          attendee: 'Alex',
          status: AttendanceStatus.present,
          recordedAt: now,
          recordedBy: 'test',
        ),
        SessionRecord(
          memberId: 'm2',
          attendee: 'Jordan',
          status: AttendanceStatus.absent,
          recordedAt: now,
          recordedBy: 'test',
        ),
      ],
      createdAt: now,
      updatedAt: now,
      createdBy: 'test',
      currentVersion: 1,
    ),
  ];

  group('ReportExportService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('reports_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('exports CSV using session repository data', () async {
      final service = ReportExportService(
        sessionRepository: _FakeSessionRepository(sessions),
        directoryProvider: () async => tempDir,
        clock: () => now,
      );

      final result = await service.exportReport(
        ReportRequest(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 12),
          format: ReportFormat.csv,
        ),
      );

      final exported = File(result.filePath);
      expect(await exported.exists(), isTrue);
      final content = await exported.readAsString();
      expect(content, contains('Morning Standup'));
      expect(content, contains('Alex'));
      expect(result.summary.recordCount, 2);
    });

    test('exports only the sessions of the given event, even after a rename',
        () async {
      Session session(String id, String title, String? eventId, int day) =>
          Session(
            id: id,
            eventId: eventId,
            title: title,
            sessionDate: DateTime(2024, 1, day),
            records: [
              SessionRecord(
                memberId: 'm$id',
                attendee: 'Person $id',
                status: AttendanceStatus.present,
                recordedAt: now,
                recordedBy: 'test',
              ),
            ],
            createdAt: now,
            updatedAt: now,
            createdBy: 'test',
          );
      // The event is now called "Sunday Worship"; older sessions kept the
      // title it had when they were recorded.
      final event = Event(
        id: 'event-1',
        title: 'Sunday Worship',
        time: const TimeOfDay(hour: 10, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
      );
      final service = ReportExportService(
        sessionRepository: _FakeSessionRepository([
          session('1', 'Sunday Service', 'event-1', 2),
          session('2', 'Sunday Worship', 'event-1', 9),
          session('3', 'Sunday Worship', 'other-event', 5),
          session('4', 'Sunday Worship', null, 6),
          session('5', 'Sunday Service', null, 7),
        ]),
        directoryProvider: () async => tempDir,
        clock: () => now,
      );

      final result = await service.exportReport(
        ReportRequest(
          startDate: DateTime(1970),
          endDate: DateTime(9999),
          format: ReportFormat.csv,
          event: event,
        ),
      );

      final content = await File(result.filePath).readAsString();
      expect(content, contains('Person 1'));
      expect(content, contains('Person 2'));
      // Another event that shares the title is not this event's session.
      expect(content, isNot(contains('Person 3')));
      // Legacy session without an event id still matches on title only.
      expect(content, contains('Person 4'));
      expect(content, isNot(contains('Person 5')));
      expect(result.summary.sessionCount, 3);
    });

    test('CSV carries a Late column with explicit values', () async {
      final lateSession = Session(
        id: '3',
        title: 'Late Standup',
        sessionDate: DateTime(2024, 1, 11),
        records: [
          SessionRecord(
            memberId: 'm4',
            attendee: 'Late Larry',
            status: AttendanceStatus.present,
            recordedAt: now,
            recordedBy: 'test',
            isLate: true,
          ),
          SessionRecord(
            memberId: 'm5',
            attendee: 'On Time Ollie',
            status: AttendanceStatus.present,
            recordedAt: now,
            recordedBy: 'test',
          ),
          SessionRecord(
            memberId: 'm6',
            attendee: 'Absent Ada',
            status: AttendanceStatus.absent,
            recordedAt: now,
            recordedBy: 'test',
          ),
        ],
        createdAt: now,
        updatedAt: now,
        createdBy: 'test',
      );
      final service = ReportExportService(
        sessionRepository: _FakeSessionRepository([lateSession]),
        directoryProvider: () async => tempDir,
        clock: () => now,
      );

      final result = await service.exportReport(
        ReportRequest(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 12),
          format: ReportFormat.csv,
        ),
      );

      final content = await File(result.filePath).readAsString();
      final lines = content.trim().split('\n');
      // Documented position: Late is the last column, beside Status.
      expect(lines.first, 'Session Date,Title,Attendee,Status,Late');
      // Every row carries an explicit value — no blanks.
      expect(lines[1], contains('present,true'));
      expect(lines[2], contains('present,false'));
      expect(lines[3], contains('absent,false'));
      // The Status column itself is untouched.
      expect(lines[1], isNot(contains('present (late)')));
      // Summary counts a late record as late and present.
      expect(result.summary.lateCount, 1);
      expect(result.summary.present, 2);
    });

  });
}
