import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:attendance_tracker/features/settings/data/drive_service.dart';
import 'package:attendance_tracker/features/settings/data/local_backup_service.dart';
import 'package:attendance_tracker/features/settings/presentation/settings_page.dart';
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
  Future<GoogleSignInAuthentication> get authentication async => throw UnimplementedError();

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

    await tester.pumpWidget(MaterialApp(
      home: SettingsPage(
        themeController: themeController,
        driveService: driveService,
        localBackupService: localBackupService,
        attendanceRepository: attendanceRepo,
      ),
    ));

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

    await tester.pumpWidget(MaterialApp(
      home: SettingsPage(
        themeController: themeController,
        driveService: driveService,
        localBackupService: localBackupService,
        attendanceRepository: attendanceRepo,
      ),
    ));

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

    await tester.pumpWidget(MaterialApp(
      home: SettingsPage(
        themeController: themeController,
        driveService: driveService,
        localBackupService: localBackupService,
        attendanceRepository: attendanceRepo,
      ),
    ));

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

    await tester.pumpWidget(MaterialApp(
      home: SettingsPage(
        themeController: themeController,
        driveService: driveService,
        localBackupService: localBackupService,
        attendanceRepository: attendanceRepo,
      ),
    ));

    await tester.tap(find.text('Version'));
    await tester.pumpAndSettle();

    expect(find.byType(AboutDialog), findsOneWidget);
    expect(find.text('Attendance Tracker'), findsOneWidget);
    // Finds twice: once in the settings tile, once in the AboutDialog
    expect(find.text('2.4.0'), findsNWidgets(2));
    expect(find.text('© 2026 Attendance Tracker Contributors'), findsOneWidget);
  });
}
