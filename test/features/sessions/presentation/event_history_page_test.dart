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

import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';

class MockAttendanceRepository implements AttendanceRepository {
  @override
  Future<List<Family>> fetchFamilies() async => [];
  @override
  Future<void> saveFamilies(List<Family> families) async {}
  @override
  Future<Family> addMember(String familyId, Member member) async =>
      throw UnimplementedError();
  @override
  Future<Family> addFamily(String displayName) async =>
      throw UnimplementedError();
  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Stream<List<Family>> streamFamilies() {
    return Stream.value([]);
  }
}

class MockSessionRepository implements SessionRepository {
  final _controller = StreamController<List<Session>>();

  void emit(List<Session> sessions) {
    _controller.add(sessions);
  }

  @override
  Stream<List<Session>> streamSessions() {
    return _controller.stream;
  }

  @override
  Future<List<Session>> loadSessions() async => [];

  @override
  Future<Session?> findSessionById(String id) async => null;

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
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
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
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

void main() {
  testWidgets('EventHistoryPage displays sessions for the event', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final mockAttendanceRepo = MockAttendanceRepository();
    final event = Event(
      id: '1',
      title: 'Morning Standup',
      time: const TimeOfDay(hour: 9, minute: 0),
      frequency: 'Daily',
      repeatingDays: ['Monday'],
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventHistoryPage(
          event: event,
          sessionRepository: mockRepo,
          attendanceRepository: mockAttendanceRepo,
        ),
      ),
    );

    final session = Session(
      id: 's1',
      title: 'Morning Standup',
      sessionDate: DateTime(2023, 10, 7),
      records: [
        SessionRecord(
          memberId: 'm1',
          attendee: 'A',
          status: AttendanceStatus.present,
          recordedAt: DateTime.now(),
          recordedBy: 'User',
        ),
        SessionRecord(
          memberId: 'm2',
          attendee: 'B',
          status: AttendanceStatus.absent,
          recordedAt: DateTime.now(),
          recordedBy: 'User',
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
      currentVersion: 1,
    );

    mockRepo.emit([session]);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Morning Standup History'), findsOneWidget);
    expect(find.text('Oct 7, 2023'), findsOneWidget);
    expect(find.text('1 Present'), findsOneWidget);
    expect(find.text('1 Absent'), findsOneWidget);
  });

  testWidgets('EventHistoryPage filters members based on event.memberIds', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    
    // Event only includes member '1'
    final event = Event(
      id: 'e1',
      title: 'Restricted Event',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'One-time',
      memberIds: ['1'],
      createdAt: DateTime.now(),
    );

    // Mock attendance repo returns 2 members
    final member1 = Member(id: '1', displayName: 'Member One');
    final member2 = Member(id: '2', displayName: 'Member Two');
    
    // Custom mock repo to return members
    final customAttendanceRepo = _MockAttendanceRepoWithMembers([member1, member2]);

    await tester.pumpWidget(
      MaterialApp(
        home: EventHistoryPage(
          event: event,
          sessionRepository: mockRepo,
          attendanceRepository: customAttendanceRepo,
        ),
      ),
    );

    final session = Session(
      id: 's1',
      title: 'Restricted Event',
      sessionDate: DateTime(2023, 10, 7),
      records: [
        SessionRecord(
          memberId: '1',
          attendee: 'Member One',
          status: AttendanceStatus.present,
          recordedAt: DateTime.now(),
          recordedBy: 'User',
        ),
        // Record for member 2 who is NOT assigned to this event
        SessionRecord(
          memberId: '2',
          attendee: 'Member Two',
          status: AttendanceStatus.present,
          recordedAt: DateTime.now(),
          recordedBy: 'User',
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
      currentVersion: 1,
    );

    mockRepo.emit([session]);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    // Member One is assigned and present -> 1 Present
    // Member Two is NOT assigned, but has a present record -> Should also count as 1 Present (visitor)
    // So total Present should be 2
    expect(find.text('2 Present'), findsOneWidget);
    
    // Only Member One is assigned. He is present. 
    // So 0 assigned members are absent.
    // Member Two is not assigned, so he shouldn't be counted as 'Absent' by default.
    expect(find.text('0 Absent'), findsOneWidget);
  });

  testWidgets('EventHistoryPage displays a FAB to make up previous sessions', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockSessionRepository();
    final mockAttendanceRepo = MockAttendanceRepository();

    final event = Event(
      id: 'e1',
      title: 'History Event',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'Weekly',
      repeatingDays: ['Monday'],
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventHistoryPage(
          event: event,
          sessionRepository: mockRepo,
          attendanceRepository: mockAttendanceRepo,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // Wait for _init delay
    await tester.pumpAndSettle();

    // Should have a FAB with Hero tag 'fab'
    final fabFinder = find.byType(FloatingActionButton);
    expect(fabFinder, findsOneWidget);
    
    final fab = tester.widget<FloatingActionButton>(fabFinder);
    expect(fab.heroTag, 'fab');
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}

class _MockAttendanceRepoWithMembers extends MockAttendanceRepository {
  final List<Member> members;
  _MockAttendanceRepoWithMembers(this.members);

  @override
  Future<List<Family>> fetchFamilies() async {
    return [Family(id: 'f1', displayName: 'Family', members: members)];
  }
}
