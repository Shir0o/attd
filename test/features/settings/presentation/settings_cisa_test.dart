import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:attendance_tracker/features/settings/data/cisa_sync_service.dart';
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
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAttendanceRepository extends AttendanceRepository {
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
  Stream<List<Family>> streamFamilies() => Stream.value([]);
}

class _MockEventRepository implements EventRepository {
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

class _MockSessionRepository implements SessionRepository {
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
  Future<Session> duplicate(String sessionId, {required String actor}) async => throw UnimplementedError();
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
  Future<Session> saveSnapshot(Session session, {required String actor}) async => session;
  @override
  Stream<List<Session>> streamSessions() => Stream.value([]);
}

class _FakeDriveService extends ChangeNotifier implements DriveService {
  @override
  DateTime? lastSyncTime;
  @override
  GoogleSignInAccount? currentUser;
  @override
  bool isDriveSyncEnabled = false;
  @override
  bool isBackgroundSyncEnabled = true;
  @override
  bool isBackgroundSyncWifiOnly = true;
  @override
  DateTime? lastBackgroundSyncTime;
  @override
  String? lastBackgroundSyncStatus;
  @override
  bool isSyncing = false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockLocalBackupService extends Mock implements LocalBackupService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SettingsPage renders CISA Campus Tracker section and saves URL and Token', (tester) async {
    SharedPreferences.setMockInitialValues({
      CisaSyncService.keyCisaSyncUrl: 'https://cisa.example.org/api/intake',
      CisaSyncService.keyCisaSyncToken: 'existing-secret-token',
    });

    final driveService = _FakeDriveService();

    final prefs = await SharedPreferences.getInstance();
    final themeController = ThemeController(prefs);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          themeController: themeController,
          driveService: driveService,
          localBackupService: _MockLocalBackupService(),
          attendanceRepository: _MockAttendanceRepository(),
          eventRepository: _MockEventRepository(),
          sessionRepository: _MockSessionRepository(),
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('CISA CAMPUS TRACKER'),
      find.byType(ListView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    expect(find.text('CISA CAMPUS TRACKER'), findsOneWidget);
    expect(find.byKey(const ValueKey('cisa_sync_url_field')), findsOneWidget);
    expect(find.byKey(const ValueKey('cisa_sync_token_field')), findsOneWidget);

    final urlFieldFinder = find.byKey(const ValueKey('cisa_sync_url_field'));
    final tokenFieldFinder = find.byKey(const ValueKey('cisa_sync_token_field'));

    expect(find.descendant(of: urlFieldFinder, matching: find.text('https://cisa.example.org/api/intake')), findsOneWidget);
    expect(find.descendant(of: tokenFieldFinder, matching: find.text('existing-secret-token')), findsOneWidget);

    await tester.enterText(urlFieldFinder, 'https://cisa.updated.org/webhook');
    await tester.enterText(tokenFieldFinder, 'new-token-456');
    await tester.pumpAndSettle();

    expect(prefs.getString(CisaSyncService.keyCisaSyncUrl), 'https://cisa.updated.org/webhook');
    expect(prefs.getString(CisaSyncService.keyCisaSyncToken), 'new-token-456');
  });
}
