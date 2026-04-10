import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:attendance_tracker/features/settings/data/drive_service.dart';
import 'package:attendance_tracker/features/settings/data/local_backup_service.dart';
import 'package:attendance_tracker/features/settings/presentation/settings_page.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAttendanceRepository implements AttendanceRepository {
  @override
  Future<Family> addFamily(String displayName) async =>
      throw UnimplementedError();
  @override
  Future<Family> addMember(String familyId, Member member) async =>
      throw UnimplementedError();
  @override
  Future<List<Family>> fetchFamilies() async => [];
  @override
  Future<void> saveFamilies(List<Family> families) async {}
  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Stream<List<Family>> streamFamilies() {
    return Stream.value([]);
  }
}

class MockEventRepository implements EventRepository {
  @override
  Future<void> createEvent(Event event) async {}
  @override
  Future<void> updateEvent(Event event) async {}
  @override
  Future<void> deleteEvent(String eventId) async {}
  @override
  Future<Event?> findEventById(String eventId) async => null;
  @override
  Stream<List<Event>> streamEvents() => Stream.value([]);
  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class MockSessionRepository implements SessionRepository {
  @override
  Future<Session> createSession({
    required String title,
    String? eventId,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async => throw UnimplementedError();
  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {}
  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async =>
      throw UnimplementedError();
  @override
  Future<Session?> findSessionById(String id) async => null;
  @override
  Future<List<SessionVersion>> history(String sessionId) async => [];
  @override
  Future<List<Session>> loadSessions() async => [];
  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
  @override
  Future<Session> saveSnapshot(
    Session session, {
    required String actor,
  }) async => throw UnimplementedError();
  @override
  Stream<List<Session>> streamSessions() => Stream.value([]);
}

class FakeDriveService extends ChangeNotifier implements DriveService {
  @override
  bool isSyncing = false;

  @override
  DateTime? lastSyncTime;

  @override
  GoogleSignInAccount? currentUser;

  @override
  bool isDriveSyncEnabled = false;

  @override
  Future<void> signIn() async {
    // Mock sign in
    currentUser = FakeGoogleSignInAccount();
    isDriveSyncEnabled = true;
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
    isDriveSyncEnabled = false;
    notifyListeners();
  }

  @override
  Future<void> setDriveSyncEnabled(bool enabled) async {
    isDriveSyncEnabled = enabled;
    notifyListeners();
  }

  @override
  Future<void> syncFiles({
    String actionTitle = 'Manual Sync',
    List<String> tags = const [],
    bool isInitialSetup = false,
  }) async {
    isSyncing = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 100));
    isSyncing = false;
    lastSyncTime = DateTime.now();
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGoogleSignInAccount implements GoogleSignInAccount {
  @override
  String get email => 'test@example.com';

  @override
  String get displayName => 'Test User';

  @override
  String get id => '123';

  @override
  String? get photoUrl => null;

  @override
  GoogleSignInAuthentication get authentication => FakeGoogleSignInAuthentication();

  @override
  GoogleSignInAuthorizationClient get authorizationClient => FakeGoogleSignInAuthorizationClient();
}

class FakeGoogleSignInAuthentication implements GoogleSignInAuthentication {
  @override
  String? get idToken => 'fake_id_token';
}

class FakeGoogleSignInAuthorizationClient implements GoogleSignInAuthorizationClient {
  @override
  Future<GoogleSignInClientAuthorization?> authorizationForScopes(List<String> scopes) async {
    return FakeGoogleSignInClientAuthorization();
  }

  @override
  Future<GoogleSignInClientAuthorization> authorizeScopes(List<String> scopes) async {
    return FakeGoogleSignInClientAuthorization();
  }

  @override
  Future<Map<String, String>?> authorizationHeaders(List<String> scopes, {bool promptIfNecessary = false}) async {
    return {'Authorization': 'Bearer fake_access_token'};
  }

  @override
  Future<GoogleSignInServerAuthorization?> authorizeServer(List<String> scopes) async => null;

  @override
  Future<void> clearAuthorizationToken({required String accessToken}) async {}
}

class FakeGoogleSignInClientAuthorization implements GoogleSignInClientAuthorization {
  @override
  String get accessToken => 'fake_access_token';
}

class FakeLocalBackupService extends LocalBackupService {
  bool backupCalled = false;
  bool exportCalled = false;

  @override
  Future<void> createBackup() async {
    backupCalled = true;
  }

  @override
  Future<void> exportData() async {
    exportCalled = true;
  }
}

void main() {
  late ThemeController themeController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    themeController = ThemeController(prefs);
  });

  testWidgets('SettingsPage shows skeleton loader while loading', (tester) async {
    final driveService = FakeDriveService();
    final localBackupService = FakeLocalBackupService();
    final attendanceRepo = MockAttendanceRepository();
    final eventRepo = MockEventRepository();
    final sessionRepo = MockSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          themeController: themeController,
          driveService: driveService,
          localBackupService: localBackupService,
          attendanceRepository: attendanceRepo,
          eventRepository: eventRepo,
          sessionRepository: sessionRepo,
        ),
      ),
    );

    // Should show skeleton initially (before pumpAndSettle)
    expect(find.byKey(const ValueKey('settings_skeleton')), findsOneWidget);

    await tester.pumpAndSettle();

    // Should show actual content after loading
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings_skeleton')), findsNothing);
  });

  testWidgets('SettingsPage renders correctly', (tester) async {
    final driveService = FakeDriveService();
    final localBackupService = FakeLocalBackupService();
    final attendanceRepo = MockAttendanceRepository();
    final eventRepo = MockEventRepository();
    final sessionRepo = MockSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          themeController: themeController,
          driveService: driveService,
          localBackupService: localBackupService,
          attendanceRepository: attendanceRepo,
          eventRepository: eventRepo,
          sessionRepository: sessionRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('Theme Mode'), findsOneWidget);
    // Section header is now uppercased "CLOUD SYNC (GOOGLE DRIVE)"
    expect(find.textContaining('CLOUD SYNC'), findsOneWidget);
    // When not signed in the "Not signed in" card is shown
    expect(find.text('Not signed in'), findsOneWidget);
    // Data Management section contains backup and export (may need scroll)
    await tester.dragUntilVisible(
      find.text('Backup to Local Storage'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('Backup to Local Storage'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Export Report'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('Export Report'), findsOneWidget);
  });

  testWidgets('SettingsPage toggles Drive Sync', (tester) async {
    final driveService = FakeDriveService();
    final localBackupService = FakeLocalBackupService();
    final attendanceRepo = MockAttendanceRepository();
    final eventRepo = MockEventRepository();
    final sessionRepo = MockSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          themeController: themeController,
          driveService: driveService,
          localBackupService: localBackupService,
          attendanceRepository: attendanceRepo,
          eventRepository: eventRepo,
          sessionRepository: sessionRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially signed out – no Switch visible, "Not signed in" card shown
    expect(driveService.currentUser, isNull);
    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);

    // Sign in via the button in the card
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(driveService.currentUser, isNotNull);
    // "Sync Now" button should appear (inline FilledButton)
    expect(find.text('Sync Now'), findsOneWidget);

    // Sign out via the dedicated button (need to scroll to find it if necessary)
    await tester.dragUntilVisible(
      find.text('Sign Out'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    // Should show confirm dialog
    expect(find.text('Sign Out?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
    await tester.pumpAndSettle();

    expect(driveService.currentUser, isNull);
    // Not signed in – card shown, Sync Now hidden
    expect(find.text('Not signed in', skipOffstage: false), findsOneWidget);
    expect(find.text('Sync Now'), findsNothing);
  });

  testWidgets('SettingsPage calls backup and export', (tester) async {
    final driveService = FakeDriveService();
    final localBackupService = FakeLocalBackupService();
    final attendanceRepo = MockAttendanceRepository();
    final eventRepo = MockEventRepository();
    final sessionRepo = MockSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          themeController: themeController,
          driveService: driveService,
          localBackupService: localBackupService,
          attendanceRepository: attendanceRepo,
          eventRepository: eventRepo,
          sessionRepository: sessionRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Backup to Local Storage'),
      find.byType(ListView),
      const Offset(0, -400),
    );
    await tester.ensureVisible(find.text('Backup to Local Storage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backup to Local Storage'));
    await tester.pump();
    expect(localBackupService.backupCalled, isTrue);

    await tester.dragUntilVisible(
      find.text('Export Report'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.ensureVisible(find.text('Export Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export Report'));
    await tester.pump();
    expect(localBackupService.exportCalled, isTrue);
  });

  testWidgets('SettingsPage shows about dialog on version tap', (tester) async {
    final driveService = FakeDriveService();
    final localBackupService = FakeLocalBackupService();
    final attendanceRepo = MockAttendanceRepository();
    final eventRepo = MockEventRepository();
    final sessionRepo = MockSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          themeController: themeController,
          driveService: driveService,
          localBackupService: localBackupService,
          attendanceRepository: attendanceRepo,
          eventRepository: eventRepo,
          sessionRepository: sessionRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('About'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.ensureVisible(find.text('About'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    // It uses a BottomSheet, not AboutDialog
    expect(find.byType(BottomSheet), findsOneWidget);

    // We can't rely on 'dialogFinder' so just look globally
    expect(find.text('Attendance Tracker', skipOffstage: false), findsWidgets);
    expect(find.text('Version 1.2.0+13', skipOffstage: false), findsWidgets);
    expect(find.text('Legalese', skipOffstage: false), findsWidgets);
  });
}
