import 'dart:async';
import 'dart:io';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/reports/report_export_page.dart';
import 'package:attendance_tracker/features/reports/report_export_service.dart';
import 'package:attendance_tracker/features/reports/report_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockSessionRepository implements SessionRepository {
  List<Session> sessions = [];
  bool throwOnLoad = false;

  @override
  Future<List<Session>> loadSessions() async {
    if (throwOnLoad) {
      throw StateError('load failed');
    }
    return sessions;
  }

  @override
  Future<Session> createSession({
    required String title,
    String? eventId,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {}

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async {
    throw UnimplementedError();
  }

  @override
  Future<Session?> findSessionById(String id) async => null;

  @override
  Future<List<SessionVersion>> history(String sessionId) async => [];

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    return session;
  }

  @override
  Stream<List<Session>> streamSessions() => Stream.value(sessions);
}

class FakeReportExportService extends ReportExportService {
  FakeReportExportService({
    required SessionRepository sessionRepository,
    required this.result,
    this.error,
    this.supportsSheets = true,
  }) : super(sessionRepository: sessionRepository);

  final ReportExportResult result;
  final Object? error;
  final bool supportsSheets;
  ReportRequest? lastRequest;

  @override
  bool get supportsGoogleSheets => supportsSheets;

  @override
  Future<ReportExportResult> exportReport(ReportRequest request) async {
    lastRequest = request;
    if (error != null) {
      throw error!;
    }
    return result;
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('report_export_page_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('ReportExportPage renders controls', (WidgetTester tester) async {
    final mockRepo = MockSessionRepository();
    // Add dummy sessions so event chips appear
    mockRepo.sessions = [
      Session(
        id: '1',
        title: 'Event A',
        sessionDate: DateTime.now(),
        records: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'User',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: ReportExportPage(sessionRepository: mockRepo)),
    );
    await tester.pumpAndSettle();

    // Check date range
    expect(find.text('Reporting window'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);

    // Check event chips
    expect(find.text('Select Events'), findsOneWidget);
    expect(find.text('Event A'), findsOneWidget);

    // Check format dropdown
    expect(find.text('Output format'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);

    expect(find.text('Generate report', skipOffstage: false), findsOneWidget);

    // Accessibility check
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('ReportExportPage filters events, exports, and copies path', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final now = DateTime(2026, 5, 17, 10);
    final exportPath = '${tempDir.path}/attendance_report_test.pdf';
    mockRepo.sessions = [
      Session(
        id: '1',
        title: 'Event A',
        sessionDate: now,
        records: [
          SessionRecord(
            attendee: 'Alice',
            status: AttendanceStatus.present,
            recordedAt: now,
            recordedBy: 'tester',
          ),
        ],
        createdAt: now,
        updatedAt: now,
        createdBy: 'User',
      ),
      Session(
        id: '2',
        title: 'Event B',
        sessionDate: now,
        records: [
          SessionRecord(
            attendee: 'Bob',
            status: AttendanceStatus.absent,
            recordedAt: now,
            recordedBy: 'tester',
          ),
        ],
        createdAt: now,
        updatedAt: now,
        createdBy: 'User',
      ),
    ];
    final exportService = FakeReportExportService(
      sessionRepository: mockRepo,
      result: ReportExportResult(
        filePath: exportPath,
        format: ReportFormat.pdf,
        summary: const ReportSummary(
          sessionCount: 1,
          recordCount: 1,
          present: 1,
          absent: 0,
        ),
        sheetSync: const SheetSyncResult(
          attempted: true,
          success: true,
          shareLink: 'https://example.test/report',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReportExportPage(
          sessionRepository: mockRepo,
          exportService: exportService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Event A'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Generate report'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Generate report'));
    for (var i = 0;
        i < 10 && find.text('Last export').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(exportService.lastRequest?.format, ReportFormat.csv);
    expect(exportService.lastRequest?.syncToGoogleSheets, isTrue);
    expect(exportService.lastRequest?.selectedEventTitles, ['Event A']);

    await tester.scrollUntilVisible(
      find.text('Last export'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Last export'), findsOneWidget);
    expect(find.text('Synced'), findsOneWidget);
    expect(find.textContaining('Sessions: 1, records: 1'), findsOneWidget);
    expect(find.textContaining('attendance_report_'), findsWidgets);

    expect(find.text(exportPath), findsOneWidget);

    expect(find.text('Copy Path'), findsOneWidget);
    expect(find.text('Local Copy'), findsOneWidget);
  });

  testWidgets('ReportExportPage shows export errors', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final exportService = FakeReportExportService(
      sessionRepository: mockRepo,
      result: const ReportExportResult(
        filePath: '',
        format: ReportFormat.csv,
        summary: ReportSummary(
          sessionCount: 0,
          recordCount: 0,
          present: 0,
          absent: 0,
        ),
      ),
      error: StateError('load failed'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReportExportPage(
          sessionRepository: mockRepo,
          exportService: exportService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate report'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bad state: load failed'), findsOneWidget);
  });
}
