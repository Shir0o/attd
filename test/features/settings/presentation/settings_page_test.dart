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

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Theme Mode'), findsOneWidget);
    expect(find.text('Cloud Sync'), findsOneWidget);
    expect(find.text('Google Drive Sync'), findsOneWidget);
    expect(find.text('Backup to Local Storage'), findsOneWidget);
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

    // Initially signed out
    expect(driveService.currentUser, isNull);
    // There are now multiple switches (one for theme, one for sync?)
    // Wait, theme uses DropdownButton, only Sync uses Switch.
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);

    // Toggle on
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(driveService.currentUser, isNotNull);

    // "Sync Now" button should appear
    expect(find.text('Sync Now'), findsOneWidget);

    // Toggle off
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(driveService.currentUser, isNull);
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

    await tester.tap(find.text('Backup to Local Storage'));
    await tester.pump();
    expect(localBackupService.backupCalled, isTrue);

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

    await tester.dragUntilVisible(
      find.text('App Version'),
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.tap(find.text('App Version'));
    await tester.pumpAndSettle();

    // It uses a BottomSheet, not AboutDialog
    expect(find.byType(BottomSheet), findsOneWidget);

    // We can't rely on 'dialogFinder' so just look globally
    expect(find.text('Attendance Tracker', skipOffstage: false), findsWidgets);
    expect(find.text('Version 1.0.12', skipOffstage: false), findsWidgets);
  });
}
