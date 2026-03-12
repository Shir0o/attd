import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/attendance/presentation/session_summary_page.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';

import '../../helpers/mocks.dart';
import '../../helpers/tolerant_comparator.dart';

void main() {
  late MockSessionRepository mockSessionRepository;

  setUp(() {
    mockSessionRepository = MockSessionRepository();
  });

  Widget buildSessionSummaryPage({
    required Session session,
    required List<Member> members,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: SessionSummaryPage(
        session: session,
        members: members,
        sessionRepository: mockSessionRepository,
      ),
    );
  }

  testWidgets('SessionSummaryPage Golden Test - Mix of Present and Absent', (
    tester,
  ) async {
    // Set a consistent surface size for golden tests
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    // Reset after test
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Set tolerance for this test file
    setupTolerantComparator('session_summary_golden_test.dart', precisionError: 0.05);

    final members = [
      Member(id: '1', displayName: 'Alice Johnson'),
      Member(id: '2', displayName: 'Bob Smith'),
      Member(id: '3', displayName: 'Charlie Brown'),
    ];

    final records = [
      SessionRecord(
        attendee: 'Alice Johnson',
        status: AttendanceStatus.present,
        recordedAt: DateTime.now(),
        recordedBy: 'User',
      ),
      SessionRecord(
        attendee: 'Bob Smith',
        status: AttendanceStatus.absent,
        recordedAt: DateTime.now(),
        recordedBy: 'User',
      ),
    ];

    final session = Session(
      id: 'session-summary-1',
      title: 'Weekly Sync',
      sessionDate: DateTime(2023, 10, 27),
      records: records,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
      currentVersion: 1,
    );

    // Seed mock repo so findSessionById works (called in initState)
    mockSessionRepository.setSessions([session]);

    await tester.pumpWidget(
      buildSessionSummaryPage(session: session, members: members),
    );

    // Wait for _refreshLatest loading
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SessionSummaryPage),
      matchesGoldenFile('goldens/session_summary_mixed.png'),
    );
  });
}
