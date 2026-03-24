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
}

class MockEventRepository implements EventRepository {
  @override
  Future<void> createEvent(Event event) async {}
  @override
  Future<void> updateEvent(Event event) async {}
  @override
  Future<void> deleteEvent(String eventId) async {}
  @override
  Stream<List<Event>> streamEvents() => Stream.value([]);
  @override
  Future<void> refresh() async {}
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
  Future<Session> saveSnapshot(
    Session session, {
    required String actor,
  }) async => throw UnimplementedError();
  @override
  Stream<List<Session>> streamSessions() => Stream.value([]);
}

// Create a Fake Drive Service
// ... (rest of the fake classes)
class FakeDriveService extends ChangeNotifier implements DriveService {
  @override
  bool isSyncing = false;

  @override
  DateTime? lastSyncTime;

  @override
  GoogleSignInAccount? currentUser;

  @override
  Future<void> signIn() async {
    // Mock sign in
    currentUser = FakeGoogleSignInAccount();
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
    notifyListeners();
  }

  @override
  Future<void> syncFiles() async {
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
  String? get serverAuthCode => null;

  @override
  Future<Map<String, String>> get authHeaders async => {};

  @override
  Future<GoogleSignInAuthentication> get authentication async =>
      throw UnimplementedError();

  @override
  Future<void> clearAuthCache() async {}
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
    // When not signed in the "Not Signed In" card is shown
    expect(find.text('Not Signed In'), findsOneWidget);
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

    // Initially signed out – no Switch visible, "Not Signed In" card shown
    expect(driveService.currentUser, isNull);
    expect(find.text('Not Signed In'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);

    // Sign in via the button in the card
    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();

    expect(driveService.currentUser, isNotNull);
    // Switch should now be visible (inside the signed-in card)
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);

    // "Sync Now" button should appear (inline FilledButton)
    expect(find.text('Sync Now'), findsOneWidget);

    // Toggle off via the switch
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(driveService.currentUser, isNull);
    // Not signed in – card shown, Sync Now hidden
    expect(find.text('Not Signed In'), findsOneWidget);
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
      const Offset(0, -500),
    );
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();

    // It uses a BottomSheet, not AboutDialog
    expect(find.byType(BottomSheet), findsOneWidget);

    // We can't rely on 'dialogFinder' so just look globally
    expect(find.text('Attendance Tracker', skipOffstage: false), findsWidgets);
    expect(find.text('Version 2.4.0', skipOffstage: false), findsWidgets);
    expect(find.text('Legalese', skipOffstage: false), findsWidgets);
  });
}
