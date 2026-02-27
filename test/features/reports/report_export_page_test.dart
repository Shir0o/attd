import 'dart:async';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/reports/report_export_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockSessionRepository implements SessionRepository {
  List<Session> sessions = [];

  @override
  Future<List<Session>> loadSessions() async => sessions;

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
  Future<void> refresh() async {}

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    return session;
  }

  @override
  Stream<List<Session>> streamSessions() => Stream.value(sessions);
}

void main() {
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
}
