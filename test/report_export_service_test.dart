import 'dart:io';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/reports/report_export_service.dart';
import 'package:attendance_tracker/features/reports/report_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository(this.sessions);

  final List<Session> sessions;

  @override
  Future<Session> createSession({
    required String title,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async => throw UnimplementedError();

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async =>
      throw UnimplementedError();

  @override
  Future<List<Session>> loadSessions({bool includeDeleted = false}) async =>
      sessions;

  @override
  Future<Session?> revertToPrevious(
    String sessionId, {
    required String actor,
  }) async => throw UnimplementedError();

  @override
  Future<Session> saveSnapshot(
    Session session, {
    required String actor,
  }) async => throw UnimplementedError();

  @override
  Future<List<SessionVersion>> history(String sessionId) async => [];
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
          attendee: 'Alex',
          status: AttendanceStatus.present,
          recordedAt: now,
          recordedBy: 'test',
        ),
        SessionRecord(
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

    test('creates image summary with attendance rate', () async {
      final service = ReportExportService(
        sessionRepository: _FakeSessionRepository(sessions),
        directoryProvider: () async => tempDir,
        clock: () => now,
      );

      final result = await service.exportReport(
        ReportRequest(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 12),
          format: ReportFormat.image,
        ),
      );

      expect(result.summary.attendanceRate, greaterThan(0));
      expect(result.filePath.endsWith('.png'), isTrue);
      expect(File(result.filePath).statSync().size, greaterThan(0));
    });

    test('respects Google Sheets sync flag when supported', () async {
      final service = ReportExportService(
        sessionRepository: _FakeSessionRepository(sessions),
        directoryProvider: () async => tempDir,
        clock: () => now,
      );

      final result = await service.exportReport(
        ReportRequest(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 12),
          format: ReportFormat.pdf,
          syncToGoogleSheets: true,
        ),
      );

      expect(result.syncedToSheets, isTrue);
    });

    test('creates a basic PDF document instead of plain text', () async {
      final service = ReportExportService(
        sessionRepository: _FakeSessionRepository(sessions),
        directoryProvider: () async => tempDir,
        clock: () => now,
      );

      final result = await service.exportReport(
        ReportRequest(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 12),
          format: ReportFormat.pdf,
        ),
      );

      final bytes = await File(result.filePath).readAsBytes();
      final asString = String.fromCharCodes(bytes);

      expect(bytes.length, greaterThan(0));
      expect(asString.startsWith('%PDF-'), isTrue);
      expect(asString, contains('/Type /Page'));
      expect(asString, contains('Attendance summary report'));
    });
  });
}
