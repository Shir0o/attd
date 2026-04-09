import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:attendance_tracker/features/settings/data/drive_service.dart';
import 'package:attendance_tracker/features/settings/data/local_backup_service.dart';
import 'package:attendance_tracker/features/settings/presentation/settings_page.dart';
import 'package:attendance_tracker/features/settings/presentation/cloud_backup_page.dart';
import 'package:attendance_tracker/features/hub/presentation/members_page.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/core/design/app_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googleapis/drive/v3.dart' as drive;

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
  Future<List<drive.File>> listCloudBackups() async => [];

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

    // Should show AppShimmer initially
    expect(find.byType(AppShimmer), findsWidgets);

    await tester.pumpAndSettle();

    // Should show actual content after loading
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(AppShimmer), findsNothing);
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
    
    expect(find.text('DATA MANAGEMENT'), findsOneWidget);
    expect(find.text('Manage Members'), findsOneWidget);
    expect(find.text('Manage Backup Data'), findsOneWidget);

    expect(find.text('BACKUP & SYNC'), findsOneWidget);
    expect(find.text('Google Drive Sync'), findsOneWidget);
  });

  testWidgets('SettingsPage navigates to subpages', (tester) async {
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

    // Test navigation to Manage Members
    await tester.tap(find.text('Manage Members'));
    await tester.pumpAndSettle();
    expect(find.byType(MembersPage), findsOneWidget);
    
    // Go back
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // Test navigation to Google Drive Sync
    await tester.tap(find.text('Google Drive Sync'));
    await tester.pumpAndSettle();
    expect(find.byType(CloudBackupPage), findsOneWidget);
  });
}
