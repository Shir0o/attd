import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/sessions/presentation/event_history_page.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';

class MockSessionRepository implements SessionRepository {
  final _controller = StreamController<List<Session>>();

  void emit(List<Session> sessions) {
    _controller.add(sessions);
  }

  @override
  Stream<List<Session>> streamSessions({bool includeDeleted = false}) {
    return _controller.stream;
  }

  @override
  Future<List<Session>> loadSessions({bool includeDeleted = false}) async => [];

  @override
  Future<Session> createSession({
    required String title,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    throw UnimplementedError();
  }

  @override
  Future<Session?> revertToPrevious(String sessionId, {required String actor}) async {
    throw UnimplementedError();
  }

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {}

  @override
  Future<List<SessionVersion>> history(String sessionId) async {
    return [];
  }

  @override
  Future<void> refresh() async {}
}

void main() {
  testWidgets('EventHistoryPage displays sessions for the event', (WidgetTester tester) async {
    final mockRepo = MockSessionRepository();
    final event = Event(
      id: '1',
      title: 'Morning Standup',
      time: const TimeOfDay(hour: 9, minute: 0),
      frequency: 'Daily',
      repeatingDays: ['Monday'],
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(MaterialApp(
      home: EventHistoryPage(
        event: event,
        sessionRepository: mockRepo,
      ),
    ));

    // Initially loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final session = Session(
      id: 's1',
      title: 'Morning Standup',
      sessionDate: DateTime(2023, 10, 7),
      records: [
        SessionRecord(attendee: 'A', status: AttendanceStatus.present, recordedAt: DateTime.now(), recordedBy: 'User'),
        SessionRecord(attendee: 'B', status: AttendanceStatus.absent, recordedAt: DateTime.now(), recordedBy: 'User'),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
      currentVersion: 1,
    );

    mockRepo.emit([session]);
    await tester.pumpAndSettle();

    expect(find.text('Morning Standup History'), findsOneWidget);
    expect(find.text('Oct 7, 2023'), findsOneWidget);
    expect(find.text('1 Present'), findsOneWidget);
    expect(find.text('1 Absent'), findsOneWidget);
  });
}
