import 'dart:io';
import 'dart:typed_data';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/reports/report_export_service.dart';
import 'package:attendance_tracker/features/reports/report_models.dart';
import 'package:attendance_tracker/features/reports/sheets_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSessionRepository implements SessionRepository {
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

class _FakeSheetsClient implements SheetsClient {
  _FakeSheetsClient({this.shouldThrow = false});

  final bool shouldThrow;
  int uploadCount = 0;

  @override
  Future<SheetSyncResult> uploadReport({
    required Uint8List bytes,
    required ReportFormat format,
    required DateTime generatedAt,
    String? suggestedFileName,
  }) async {
    uploadCount++;
    if (shouldThrow) {
      throw Exception('upload failed');
    }

    return SheetSyncResult(
      attempted: true,
      success: true,
      shareLink: 'https://sheets.test/${suggestedFileName ?? format.name}',
    );
  }
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
    late _FakeSheetsClient fakeSheetsClient;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('reports_test');
      fakeSheetsClient = _FakeSheetsClient();
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
        sheetsClient: fakeSheetsClient,
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

    test('filters exported sessions by selected event titles', () async {
      final otherSession = Session(
        id: '2',
        title: 'Evening Standup',
        sessionDate: DateTime(2024, 1, 10),
        records: [
          SessionRecord(
            memberId: 'm3',
            attendee: 'Sam',
            status: AttendanceStatus.present,
            recordedAt: now,
            recordedBy: 'test',
          ),
        ],
        createdAt: now,
        updatedAt: now,
        createdBy: 'test',
        currentVersion: 1,
      );
      final service = ReportExportService(
        sessionRepository: _FakeSessionRepository([...sessions, otherSession]),
        directoryProvider: () async => tempDir,
        clock: () => now,
        sheetsClient: fakeSheetsClient,
      );

      final result = await service.exportReport(
        ReportRequest(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 12),
          format: ReportFormat.csv,
          selectedEventTitles: const ['Evening Standup'],
        ),
      );

      final content = await File(result.filePath).readAsString();
      expect(content, contains('Evening Standup'));
      expect(content, isNot(contains('Morning Standup')));
      expect(result.summary.sessionCount, 1);
      expect(result.summary.recordCount, 1);
    });

    test('creates image summary with attendance rate', () async {
      final service = ReportExportService(
        sessionRepository: _FakeSessionRepository(sessions),
        directoryProvider: () async => tempDir,
        clock: () => now,
        sheetsClient: fakeSheetsClient,
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

    test('uploads to Sheets when requested and supported', () async {
      final service = ReportExportService(
        sessionRepository: _FakeSessionRepository(sessions),
        directoryProvider: () async => tempDir,
        clock: () => now,
        sheetsClient: fakeSheetsClient,
      );

      final result = await service.exportReport(
        ReportRequest(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 12),
          format: ReportFormat.pdf,
          syncToGoogleSheets: true,
        ),
      );

      expect(result.sheetSync?.attempted, isTrue);
      expect(result.sheetSync?.success, isTrue);
      expect(result.sheetSync?.shareLink, isNotEmpty);
      expect(fakeSheetsClient.uploadCount, 1);
    });

    test('skips upload when sync flag is disabled', () async {
      final service = ReportExportService(
        sessionRepository: _FakeSessionRepository(sessions),
        directoryProvider: () async => tempDir,
        clock: () => now,
        sheetsClient: fakeSheetsClient,
      );

      final result = await service.exportReport(
        ReportRequest(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 12),
          format: ReportFormat.pdf,
          syncToGoogleSheets: false,
        ),
      );

      expect(result.sheetSync, isNull);
      expect(fakeSheetsClient.uploadCount, 0);
    });

    test('reports upload failure without throwing', () async {
      final failingClient = _FakeSheetsClient(shouldThrow: true);
      final service = ReportExportService(
        sessionRepository: _FakeSessionRepository(sessions),
        directoryProvider: () async => tempDir,
        clock: () => now,
        sheetsClient: failingClient,
      );

      final result = await service.exportReport(
        ReportRequest(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 12),
          format: ReportFormat.csv,
          syncToGoogleSheets: true,
        ),
      );

      expect(result.sheetSync?.attempted, isTrue);
      expect(result.sheetSync?.success, isFalse);
      expect(result.sheetSync?.error, contains('upload failed'));
    });

    test('creates a basic PDF document instead of plain text', () async {
      final service = ReportExportService(
        sessionRepository: _FakeSessionRepository(sessions),
        directoryProvider: () async => tempDir,
        clock: () => now,
        sheetsClient: fakeSheetsClient,
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
        sheetsClient: fakeSheetsClient,
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

    test('PDF summary and record lines carry lateness', () async {
      final lateSession = Session(
        id: '4',
        title: 'PDF Session',
        sessionDate: DateTime(2024, 1, 11),
        records: [
          SessionRecord(
            memberId: 'm1',
            attendee: 'Late Larry',
            status: AttendanceStatus.present,
            recordedAt: now,
            recordedBy: 'test',
            isLate: true,
          ),
          SessionRecord(
            memberId: 'm2',
            attendee: 'On Time Ollie',
            status: AttendanceStatus.present,
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
        sheetsClient: fakeSheetsClient,
      );

      final result = await service.exportReport(
        ReportRequest(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 12),
          format: ReportFormat.pdf,
        ),
      );

      final asString =
          String.fromCharCodes(await File(result.filePath).readAsBytes());
      // Summary line states the late count.
      expect(asString, contains('Late: 1'));
      // The PDF writer escapes parens in content streams.
      expect(asString, contains(r'Late Larry: present \(late\)'));
      expect(asString, contains('On Time Ollie: present'));
    });

    test('image summary carries the late count', () async {
      final lateSession = Session(
        id: '5',
        title: 'Image Session',
        sessionDate: DateTime(2024, 1, 11),
        records: [
          SessionRecord(
            memberId: 'm1',
            attendee: 'Late Larry',
            status: AttendanceStatus.present,
            recordedAt: now,
            recordedBy: 'test',
            isLate: true,
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
        sheetsClient: fakeSheetsClient,
      );

      final result = await service.exportReport(
        ReportRequest(
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 12),
          format: ReportFormat.image,
        ),
      );

      expect(result.summary.lateCount, 1);
      expect(result.summary.present, 1);
      // The line the image renderer draws carries the late count.
      expect(
        service.imageSummaryLines([lateSession], result.summary),
        contains('Late: 1'),
      );
      expect(result.filePath.endsWith('.png'), isTrue);
    });
  });
}
