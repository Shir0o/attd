import 'dart:async';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/auth/domain/entities/credentials.dart';
import 'package:attendance_tracker/features/auth/domain/entities/google_account.dart';
import 'package:attendance_tracker/features/auth/domain/entities/user.dart';
import 'package:attendance_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/onboarding/application/onboarding_controller.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:attendance_tracker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockEventRepository implements EventRepository {
  final _controller = StreamController<List<Event>>();

  void emit(List<Event> events) {
    _controller.add(events);
  }

  @override
  Future<void> createEvent(Event event) async {}

  @override
  Future<void> updateEvent(Event event) async {}

  @override
  Future<void> deleteEvent(String eventId) async {}

  @override
  Stream<List<Event>> streamEvents() {
    return _controller.stream;
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class MockAttendanceRepository implements AttendanceRepository {
  @override
  Future<List<Family>> fetchFamilies() async => [];

  @override
  Future<void> saveFamilies(List<Family> families) async {}

  @override
  Future<Family> addMember(String familyId, Member member) async {
    throw UnimplementedError();
  }

  @override
  Future<Family> addFamily(String displayName) async {
    throw UnimplementedError();
  }

  @override
  Stream<List<Family>> streamFamilies() {
    return Stream.value([]);
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class MockSessionRepository implements SessionRepository {
  @override
  Stream<List<Session>> streamSessions() {
    return Stream.value([]);
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
  Future<List<Session>> loadSessions() async => [];

  @override
  Future<Session?> findSessionById(String id) async => null;

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    return session;
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

class MockAuthRepository implements AuthRepository {
  @override
  Future<User?> currentUser() async =>
      const User(id: 'test', email: 'test@test.com', displayName: 'Test User');

  @override
  Future<User> login(Credentials credentials) async =>
      throw UnimplementedError();

  @override
  Future<User> loginWithGoogle(GoogleAccount account) async =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<User> signup(Credentials credentials) async =>
      throw UnimplementedError();
  }

  void main() {

  testWidgets('AttendanceApp loads HubPage without BottomNavigationBar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    final prefs = await SharedPreferences.getInstance();
    final themeController = ThemeController(prefs);
    final onboardingController = OnboardingController(prefs);

    final mockEventRepo = MockEventRepository();
    final mockSessionRepo = MockSessionRepository();
    final mockAttendanceRepo = MockAttendanceRepository();
    final mockAuthRepo = MockAuthRepository();

    // Emit empty list to stop loading spinner
    mockEventRepo.emit([]);

    await tester.pumpWidget(
      AttendanceApp(
        themeController: themeController,
        onboardingController: onboardingController,
        repository: mockAttendanceRepo,
        sessionRepository: mockSessionRepo,
        eventRepository: mockEventRepo,
        authRepository: mockAuthRepo,
      ),
    );

    // Initial pump
    await tester.pump();
    // Animation pump/settle
    await tester.pumpAndSettle();

    // Verify NavigationBar does NOT exist
    expect(find.byType(NavigationBar), findsNothing);

    // Verify default view is Attendance (HubAttendanceView)
    // "TODAY" text should be visible (from HubAttendanceView)
    expect(find.text('TODAY'), findsOneWidget);
  });
}
