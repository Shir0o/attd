import 'dart:async';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/auth/domain/entities/credentials.dart';
import 'package:attendance_tracker/features/auth/domain/entities/google_account.dart';
import 'package:attendance_tracker/features/auth/domain/entities/user.dart';
import 'package:attendance_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:attendance_tracker/features/settings/application/app_lock_controller.dart';
import 'package:attendance_tracker/features/settings/data/drive_service.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
import 'package:google_fonts/google_fonts.dart';

class MockEventRepository implements EventRepository {
  final _controller = StreamController<List<Event>>.broadcast();

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
  Future<Event?> findEventById(String eventId) async => null;

  @override
  Stream<List<Event>> streamEvents() {
    return _controller.stream;
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class MockAttendanceRepository extends AttendanceRepository {
  @override
  Future<List<Family>> fetchFamilies() async => [];

  @override
  Future<void> saveFamilies(List<Family> families) async {}

  @override
  Future<Family> addMember(String familyId, Member member) async {
    throw UnimplementedError();
  }

  @override
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) async {
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
  setUpAll(() {
    // Disable runtime fetching for Google Fonts in tests
    GoogleFonts.config.allowRuntimeFetching = false;
  });

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

    // Emit empty list to stop loading
    mockEventRepo.emit([]);

    await tester.pumpWidget(
      AttendanceApp(
        themeController: themeController,
        onboardingController: onboardingController,
        repository: mockAttendanceRepo,
        sessionRepository: mockSessionRepo,
        eventRepository: mockEventRepo,
        authRepository: mockAuthRepo,
        prefs: prefs,
      ),
    );

    // Initial pump
    await tester.pump();
    // Wait for skeleton (800ms) - pump a fixed duration to avoid animations causing timeout
    await tester.pump(const Duration(milliseconds: 1500));

    // Verify NavigationBar does NOT exist
    expect(find.byType(NavigationBar), findsNothing);

    // Verify default view is Attendance Hub
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('AttendanceApp renders onboarding when not completed',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final themeController = ThemeController(prefs);
    final onboardingController = OnboardingController(prefs);

    await tester.pumpWidget(
      AttendanceApp(
        themeController: themeController,
        onboardingController: onboardingController,
        repository: MockAttendanceRepository(),
        sessionRepository: MockSessionRepository(),
        eventRepository: MockEventRepository(),
        authRepository: MockAuthRepository(),
        prefs: prefs,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Onboarding page renders some welcome content; HubPage's "Attendance Hub"
    // header should be absent.
    expect(find.text('Today'), findsNothing);
  });

  testWidgets('AttendanceApp triggers migration when families have unique names',
      (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    final prefs = await SharedPreferences.getInstance();
    final themeController = ThemeController(prefs);
    final onboardingController = OnboardingController(prefs);

    final attendanceRepo = _RecordingAttendanceRepository(families: [
      Family(
        id: 'fam1',
        displayName: 'Smith',
        members: [
          Member(id: 'm1', displayName: 'Alice Smith'),
          Member(id: 'm2', displayName: 'Bob Smith'),
        ],
      ),
    ]);
    final sessionRepo = _RecordingSessionRepository();
    final eventRepo = MockEventRepository()..emit([]);

    await tester.pumpWidget(
      AttendanceApp(
        themeController: themeController,
        onboardingController: onboardingController,
        repository: attendanceRepo,
        sessionRepository: sessionRepo,
        eventRepository: eventRepo,
        prefs: prefs,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    expect(sessionRepo.migrateCalls, hasLength(1));
    expect(sessionRepo.migrateCalls.first, {
      'Alice Smith': 'm1',
      'Bob Smith': 'm2',
    });
  });

  testWidgets('AttendanceApp swallows migration errors', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    final prefs = await SharedPreferences.getInstance();
    final themeController = ThemeController(prefs);
    final onboardingController = OnboardingController(prefs);

    final attendanceRepo = _RecordingAttendanceRepository(families: [
      Family(
        id: 'fam1',
        displayName: 'Smith',
        members: [Member(id: 'm1', displayName: 'Solo')],
      ),
    ]);
    final sessionRepo = _ThrowingMigrateSessionRepository();
    final eventRepo = MockEventRepository()..emit([]);

    await tester.pumpWidget(
      AttendanceApp(
        themeController: themeController,
        onboardingController: onboardingController,
        repository: attendanceRepo,
        sessionRepository: sessionRepo,
        eventRepository: eventRepo,
        prefs: prefs,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    // migrate was called but threw; app didn't crash.
    expect(sessionRepo.migrateAttempts, 1);
  });

  testWidgets('AttendanceApp lifecycle paused triggers drive sync and lock',
      (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    final prefs = await SharedPreferences.getInstance();
    final themeController = ThemeController(prefs);
    final onboardingController = OnboardingController(prefs);
    final appLockController = _RecordingAppLockController(prefs);
    final driveService = _RecordingDriveService()..isDriveSyncEnabled = true;

    final eventRepo = MockEventRepository()..emit([]);

    await tester.pumpWidget(
      AttendanceApp(
        themeController: themeController,
        onboardingController: onboardingController,
        appLockController: appLockController,
        driveService: driveService,
        repository: MockAttendanceRepository(),
        sessionRepository: MockSessionRepository(),
        eventRepository: eventRepo,
        prefs: prefs,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(appLockController.markBackgroundedCalls, 1);
    expect(driveService.syncCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(appLockController.onResumedCalls, 1);

    // Disabled sync should still mark backgrounded but skip syncFiles.
    driveService.isDriveSyncEnabled = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    await tester.pump();
    expect(appLockController.markBackgroundedCalls, 2);
    expect(driveService.syncCalls, 1);
  });
}

class _RecordingAttendanceRepository extends AttendanceRepository {
  _RecordingAttendanceRepository({required this.families});
  final List<Family> families;

  @override
  Future<List<Family>> fetchFamilies() async => families;
  @override
  Future<void> saveFamilies(List<Family> families) async {}
  @override
  Future<Family> addMember(String familyId, Member member) async =>
      throw UnimplementedError();
  @override
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) async =>
      throw UnimplementedError();
  @override
  Stream<List<Family>> streamFamilies() => Stream.value(families);
  @override
  Future<void> refresh() async {}
  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class _RecordingSessionRepository extends MockSessionRepository {
  final List<Map<String, String>> migrateCalls = [];

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {
    migrateCalls.add(Map.of(nameToIdMap));
  }
}

class _ThrowingMigrateSessionRepository extends MockSessionRepository {
  int migrateAttempts = 0;

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {
    migrateAttempts++;
    throw StateError('boom');
  }
}

class _RecordingAppLockController extends AppLockController {
  _RecordingAppLockController(super.prefs);
  int markBackgroundedCalls = 0;
  int onResumedCalls = 0;

  @override
  void markBackgrounded() {
    markBackgroundedCalls++;
    super.markBackgrounded();
  }

  @override
  void onResumed() {
    onResumedCalls++;
    super.onResumed();
  }
}

class _RecordingDriveService extends ChangeNotifier implements DriveService {
  int syncCalls = 0;
  int initCalls = 0;

  @override
  bool isDriveSyncEnabled = false;
  @override
  bool isSyncing = false;
  @override
  DateTime? lastSyncTime;
  @override
  GoogleSignInAccount? currentUser;

  @override
  Future<void> init() async {
    initCalls++;
  }

  @override
  Future<void> syncFiles({
    String actionTitle = 'Manual Sync',
    List<String> tags = const [],
    bool isInitialSetup = false,
  }) async {
    syncCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
