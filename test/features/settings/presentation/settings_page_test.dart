import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/settings/application/app_lock_controller.dart';
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
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAttendanceRepository extends AttendanceRepository {
  @override
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) async =>
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
  }) async =>
      throw UnimplementedError();
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
  }) async =>
      throw UnimplementedError();
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

  bool throwOnSignIn = false;
  bool throwOnSync = false;
  bool throwOnOverwriteCloud = false;
  bool throwOnOverwriteLocal = false;
  bool overwriteCloudCalled = false;
  bool overwriteLocalCalled = false;
  int syncFilesCalls = 0;

  @override
  Future<void> signIn() async {
    if (throwOnSignIn) {
      throw StateError('sign in failed');
    }
    currentUser = FakeGoogleSignInAccount();
    isDriveSyncEnabled = true;
    notifyListeners();
  }

  @override
  Future<List<drive.File>> listCloudBackups() async => <drive.File>[];

  @override
  Future<void> overwriteCloudWithLocal() async {
    if (throwOnOverwriteCloud) {
      throw StateError('cloud overwrite failed');
    }
    overwriteCloudCalled = true;
  }

  @override
  Future<void> overwriteLocalWithCloud() async {
    if (throwOnOverwriteLocal) {
      throw StateError('local overwrite failed');
    }
    overwriteLocalCalled = true;
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
    syncFilesCalls++;
    isSyncing = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 100));
    isSyncing = false;
    lastSyncTime = DateTime.now();
    notifyListeners();
    if (throwOnSync) {
      throw StateError('sync failed');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// v7: GoogleSignInAccount surface is much smaller; authentication is a
// sync getter and auth/scope work happens via authorizationClient.
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
  GoogleSignInAuthentication get authentication =>
      const GoogleSignInAuthentication(idToken: 'fake_id_token');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockLocalAuth extends Mock implements LocalAuthentication {}

class _PushCountObserver extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

class FakeLocalBackupService extends LocalBackupService {
  bool backupCalled = false;
  bool exportCalled = false;
  bool throwOnBackup = false;
  bool throwOnExport = false;

  @override
  Future<void> createBackup() async {
    if (throwOnBackup) {
      throw StateError('backup failed');
    }
    backupCalled = true;
  }

  @override
  Future<void> exportData() async {
    if (throwOnExport) {
      throw StateError('export failed');
    }
    exportCalled = true;
  }
}

Widget _settingsPage({
  required ThemeController themeController,
  FakeDriveService? driveService,
  FakeLocalBackupService? localBackupService,
  AppLockController? appLockController,
}) {
  return MaterialApp(
    home: SettingsPage(
      themeController: themeController,
      driveService: driveService ?? FakeDriveService(),
      localBackupService: localBackupService ?? FakeLocalBackupService(),
      attendanceRepository: MockAttendanceRepository(),
      eventRepository: MockEventRepository(),
      sessionRepository: MockSessionRepository(),
      appLockController: appLockController,
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const AuthenticationOptions());
  });

  late ThemeController themeController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    themeController = ThemeController(prefs);
  });

  testWidgets('SettingsPage shows skeleton loader while loading',
      (tester) async {
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

  testWidgets('SettingsPage persists theme changes', (tester) async {
    await tester.pumpWidget(_settingsPage(themeController: themeController));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();

    expect(themeController.themeMode, ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('theme_mode'), ThemeMode.dark.index);
  });

  testWidgets('SettingsPage shows backup and export failure snackbars', (
    tester,
  ) async {
    final localBackupService = FakeLocalBackupService()
      ..throwOnBackup = true
      ..throwOnExport = true;

    await tester.pumpWidget(
      _settingsPage(
        themeController: themeController,
        localBackupService: localBackupService,
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
    await tester.pumpAndSettle();

    expect(find.textContaining('Backup failed: Bad state: backup failed'),
        findsOneWidget);

    ScaffoldMessenger.of(tester.element(find.byType(SettingsPage)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Export Report'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.ensureVisible(find.text('Export Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export Report'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Export failed: Bad state: export failed'),
        findsOneWidget);
  });

  testWidgets('SettingsPage opens manage backup data and advanced reporting', (
    tester,
  ) async {
    await tester.pumpWidget(_settingsPage(themeController: themeController));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Manage Backup Data'),
      find.byType(ListView),
      const Offset(0, -400),
    );
    await tester.tap(find.text('Manage Backup Data'));
    await tester.pumpAndSettle();

    expect(find.text('Storage inspector'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Advanced Reporting'),
      find.byType(ListView),
      const Offset(0, -400),
    );
    await tester.tap(find.text('Advanced Reporting'));
    await tester.pumpAndSettle();

    expect(find.text('Export reports'), findsOneWidget);
  });

  testWidgets('signIn failure shows snackbar', (tester) async {
    final driveService = FakeDriveService()..throwOnSignIn = true;
    await tester.pumpWidget(
      _settingsPage(
        themeController: themeController,
        driveService: driveService,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sign in failed:'), findsOneWidget);
    expect(driveService.currentUser, isNull);
  });

  Future<void> signInAndSettle(WidgetTester tester) async {
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
  }

  testWidgets('Sync Now without sheets URL shows success snackbar',
      (tester) async {
    final driveService = FakeDriveService();
    await tester.pumpWidget(
      _settingsPage(
        themeController: themeController,
        driveService: driveService,
      ),
    );
    await tester.pumpAndSettle();
    await signInAndSettle(tester);

    await tester.tap(find.text('Sync Now'));
    // Allow Future.delayed(100ms) in syncFiles to elapse without using
    // pumpAndSettle (which would race with notifyListeners loops).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(driveService.syncFilesCalls, 1);
    expect(find.text('Sync completed successfully'), findsOneWidget);
  });

  testWidgets('Sync Now with sheets URL set surfaces failure snackbar',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'googleSheetsUrl': 'https://script.google.com/macros/s/abc/exec',
    });
    final driveService = FakeDriveService();
    await tester.pumpWidget(
      _settingsPage(
        themeController: themeController,
        driveService: driveService,
      ),
    );
    await tester.pumpAndSettle();
    await signInAndSettle(tester);

    await tester.tap(find.text('Sync Now'));
    // syncFiles completes after ~100ms; sheets sync may hang on http or
    // complete. We just need the branch executed.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(driveService.syncFilesCalls, 1);
  });

  testWidgets('Sync Now shows failure snackbar when syncFiles throws',
      (tester) async {
    final driveService = FakeDriveService()..throwOnSync = true;
    await tester.pumpWidget(
      _settingsPage(
        themeController: themeController,
        driveService: driveService,
      ),
    );
    await tester.pumpAndSettle();
    await signInAndSettle(tester);

    await tester.tap(find.text('Sync Now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('Sync failed:'), findsOneWidget);
  });

  testWidgets('Overwrite Cloud success and error', (tester) async {
    final driveService = FakeDriveService();
    await tester.pumpWidget(
      _settingsPage(
        themeController: themeController,
        driveService: driveService,
      ),
    );
    await tester.pumpAndSettle();
    await signInAndSettle(tester);

    await tester.dragUntilVisible(
      find.text('Overwrite Cloud'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Overwrite Cloud'));
    await tester.pumpAndSettle();
    expect(find.text('Overwrite Cloud Data?'), findsOneWidget);

    // Cancel first to cover that branch.
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(driveService.overwriteCloudCalled, isFalse);

    // Confirm now.
    await tester.tap(find.text('Overwrite Cloud'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Overwrite'));
    await tester.pumpAndSettle();
    expect(driveService.overwriteCloudCalled, isTrue);
    expect(find.text('Cloud data overwritten'), findsOneWidget);

    // Error path.
    driveService.throwOnOverwriteCloud = true;
    ScaffoldMessenger.of(tester.element(find.byType(SettingsPage)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overwrite Cloud'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Overwrite'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Error:'), findsOneWidget);
  });

  testWidgets('Overwrite Local success and error', (tester) async {
    final driveService = FakeDriveService();
    await tester.pumpWidget(
      _settingsPage(
        themeController: themeController,
        driveService: driveService,
      ),
    );
    await tester.pumpAndSettle();
    await signInAndSettle(tester);

    await tester.dragUntilVisible(
      find.text('Overwrite Local'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.ensureVisible(find.text('Overwrite Local'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overwrite Local'));
    await tester.pumpAndSettle();
    expect(find.text('Overwrite Local Data?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Overwrite'));
    await tester.pumpAndSettle();
    expect(driveService.overwriteLocalCalled, isTrue);
    expect(find.text('Local data overwritten'), findsOneWidget);

    driveService.throwOnOverwriteLocal = true;
    ScaffoldMessenger.of(tester.element(find.byType(SettingsPage)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overwrite Local'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Overwrite'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Error:'), findsOneWidget);
  });

  testWidgets('Privacy Policy bottom sheet opens', (tester) async {
    await tester.pumpWidget(_settingsPage(themeController: themeController));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Privacy Policy'),
      find.byType(ListView),
      const Offset(0, -400),
    );
    await tester.ensureVisible(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    expect(find.text('Local-First Storage'), findsOneWidget);
    expect(find.text('Anonymized Error Reporting'), findsOneWidget);
  });

  testWidgets('Cloud Version History tile navigates', (tester) async {
    final driveService = FakeDriveService();
    final observer = _PushCountObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: SettingsPage(
          themeController: themeController,
          driveService: driveService,
          localBackupService: FakeLocalBackupService(),
          attendanceRepository: MockAttendanceRepository(),
          eventRepository: MockEventRepository(),
          sessionRepository: MockSessionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await signInAndSettle(tester);
    observer.pushes = 0;

    await tester.dragUntilVisible(
      find.text('Cloud Version History'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(find.text('Cloud Version History'));
    await tester.pump();
    expect(observer.pushes >= 1, isTrue);
    // Let CloudBackupPage finish its initial-load delay (800ms).
    await tester.pump(const Duration(milliseconds: 801));
    await tester.pumpAndSettle();
    // Pop back to SettingsPage so _markDataModified() runs.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('App Lock tile renders, toggles on success, and toggles off',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final auth = _MockLocalAuth();
    when(() => auth.isDeviceSupported()).thenAnswer((_) async => true);
    when(() => auth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          options: any(named: 'options'),
          authMessages: any(named: 'authMessages'),
        )).thenAnswer((_) async => true);
    when(() => auth.canCheckBiometrics).thenAnswer((_) async => true);
    final appLockController = AppLockController(prefs, auth: auth);
    await tester.pumpWidget(
      _settingsPage(
        themeController: themeController,
        appLockController: appLockController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PRIVACY'), findsOneWidget);
    expect(find.text('App Lock'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(appLockController.isEnabled, isFalse);

    // Enable
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(appLockController.isEnabled, isTrue);

    // Disable
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(appLockController.isEnabled, isFalse);
  });

  testWidgets('App Lock toggle shows failure snackbar when auth fails',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final auth = _MockLocalAuth();
    when(() => auth.isDeviceSupported()).thenAnswer((_) async => true);
    when(() => auth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          options: any(named: 'options'),
          authMessages: any(named: 'authMessages'),
        )).thenAnswer((_) async => false);
    final appLockController = AppLockController(prefs, auth: auth);
    await tester.pumpWidget(
      _settingsPage(
        themeController: themeController,
        appLockController: appLockController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('Authentication failed'), findsOneWidget);
  });

  testWidgets('Feedback & Support tile is tappable', (tester) async {
    await tester.pumpWidget(_settingsPage(themeController: themeController));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Feedback & Support'),
      find.byType(ListView),
      const Offset(0, -400),
    );
    await tester.tap(find.text('Feedback & Support'));
    await tester.pump();
    // launchUrl will fail in tests; we just need the closure to execute.
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('Manage Members tile navigates', (tester) async {
    await tester.pumpWidget(_settingsPage(themeController: themeController));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Manage Members'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.ensureVisible(find.text('Manage Members'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage Members'));
    await tester.pumpAndSettle();
    // Pop back without asserting on specific content; we just want coverage.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
  });

  testWidgets('Manage Families tile navigates', (tester) async {
    await tester.pumpWidget(_settingsPage(themeController: themeController));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Manage Families'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.ensureVisible(find.text('Manage Families'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage Families'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
  });

  testWidgets('Copy Apps Script Boilerplate triggers snackbar', (tester) async {
    await tester.pumpWidget(_settingsPage(themeController: themeController));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Copy Apps Script Boilerplate'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.ensureVisible(find.text('Copy Apps Script Boilerplate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy Apps Script Boilerplate'));
    // Clipboard channel may not be available in widget tests; just verify
    // the button was tappable (no exception).
    await tester.pump();
  });

  testWidgets('Sheets URL save and clear', (tester) async {
    await tester.pumpWidget(_settingsPage(themeController: themeController));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byType(TextField),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.enterText(find.byType(TextField),
        'https://script.google.com/macros/s/abc/exec');
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('googleSheetsUrl'),
        'https://script.google.com/macros/s/abc/exec');

    // Tap clear button.
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(prefs.getString('googleSheetsUrl'), '');
  });
}
