import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/hub/presentation/hub_attendance_view.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'dart:async';

class CounterSessionRepository implements SessionRepository {
  int findSessionByIdCount = 0;
  final _sessionsController = StreamController<List<Session>>.broadcast();

  @override
  Stream<List<Session>> streamSessions() => _sessionsController.stream;

  @override
  Future<Session> createSession({
    required String title,
    String? eventId,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async {
    final s = Session(
      id: 'session-1',
      eventId: eventId,
      title: title,
      sessionDate: sessionDate,
      records: records,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: actor,
      currentVersion: 1,
    );
    return s;
  }

  @override
  Future<List<Session>> loadSessions() async => [];

  @override
  Future<Session?> findSessionById(String id) async {
    findSessionByIdCount++;
    return Session(
      id: id,
      title: 'Mock Session',
      sessionDate: DateTime.now(),
      records: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'System',
    );
  }

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async => session;
  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async => throw UnimplementedError();
  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {}
  @override
  Future<List<SessionVersion>> history(String sessionId) async => [];
  @override
  Future<void> refresh() async {}
}

class SimpleEventRepository implements EventRepository {
  final _controller = StreamController<List<Event>>.broadcast();
  @override
  Future<void> createEvent(Event event) async {}
  @override
  Future<void> updateEvent(Event event) async {}
  @override
  Future<void> deleteEvent(String eventId) async {}
  @override
  Stream<List<Event>> streamEvents() => _controller.stream;
  @override
  Future<void> refresh() async {}
  void emit(List<Event> events) => _controller.add(events);
}

class SimpleAttendanceRepository implements AttendanceRepository {
  @override
  Future<List<Family>> fetchFamilies() async => [];
  @override
  Future<void> saveFamilies(List<Family> families) async {}
  @override
  Future<Family> addMember(String familyId, Member member) async => throw UnimplementedError();
  @override
  Future<Family> addFamily(String displayName) async => throw UnimplementedError();
  @override
  Future<void> refresh() async {}
}

void main() {
  testWidgets('Benchmark: findSessionById count during cleanup', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final themeController = ThemeController(prefs);

    final sessionRepo = CounterSessionRepository();
    final eventRepo = SimpleEventRepository();
    final attendanceRepo = SimpleAttendanceRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HubAttendanceView(
          sessionRepository: sessionRepo,
          eventRepository: eventRepo,
          attendanceRepository: attendanceRepo,
          themeController: themeController,
        ),
      ),
    );

    final event = Event(
      id: 'event-1',
      title: 'Test Event',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'One-time',
      oneTimeDate: DateTime.now(),
      createdAt: DateTime.now(),
    );

    eventRepo.emit([event]);
    // Also emit an existing session so it goes into the "isIncomplete" branch
    final existingSession = Session(
      id: 'session-1',
      eventId: 'event-1',
      title: 'Test Event',
      sessionDate: DateTime.now(),
      records: [], // Empty, so it will be considered incomplete
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
    );
    sessionRepo._sessionsController.add([existingSession]);

    await tester.pumpAndSettle();

    // Tap on the event card
    await tester.tap(find.text('Test Event'));
    await tester.pumpAndSettle();

    // Now we should be on the AttendanceDeckPage.
    // We need to pop it to trigger the cleanup logic.
    // The AttendanceDeckPage has a close button.
    final closeButton = find.byIcon(Icons.close);
    expect(closeButton, findsOneWidget);
    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    print('VERIFICATION: findSessionById was called ${sessionRepo.findSessionByIdCount} times');
    // Expect 0 calls in the optimized implementation
    expect(sessionRepo.findSessionByIdCount, 0);
  });
}
