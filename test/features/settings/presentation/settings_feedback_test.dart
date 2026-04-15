import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:attendance_tracker/features/settings/data/drive_service.dart';
import 'package:attendance_tracker/features/settings/data/local_backup_service.dart';
import 'package:attendance_tracker/features/settings/presentation/settings_page.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class MockThemeController extends Mock implements ThemeController {}
class MockDriveService extends Mock implements DriveService {}
class MockLocalBackupService extends Mock implements LocalBackupService {}
class MockAttendanceRepository extends Mock implements AttendanceRepository {}
class MockEventRepository extends Mock implements EventRepository {}
class MockSessionRepository extends Mock implements SessionRepository {}

class MockUrlLauncher extends Mock
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    this.url = url;
    return true;
  }

  String? url;
}

void main() {
  late ThemeController themeController;
  late MockDriveService driveService;
  late MockLocalBackupService localBackupService;
  late MockAttendanceRepository attendanceRepo;
  late MockEventRepository eventRepo;
  late MockSessionRepository sessionRepo;
  late MockUrlLauncher mockUrlLauncher;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    themeController = ThemeController(prefs);
    driveService = MockDriveService();
    localBackupService = MockLocalBackupService();
    attendanceRepo = MockAttendanceRepository();
    eventRepo = MockEventRepository();
    sessionRepo = MockSessionRepository();
    mockUrlLauncher = MockUrlLauncher();
    UrlLauncherPlatform.instance = mockUrlLauncher;

    when(() => driveService.currentUser).thenReturn(null);
    when(() => driveService.isSyncing).thenReturn(false);
    when(() => driveService.lastSyncTime).thenReturn(null);
    when(() => driveService.isDriveSyncEnabled).thenReturn(false);
    
    // Add missing stubs for stream methods
    when(() => attendanceRepo.streamFamilies()).thenAnswer((_) => Stream.value([]));
    when(() => eventRepo.streamEvents()).thenAnswer((_) => Stream.value([]));
    when(() => sessionRepo.streamSessions()).thenAnswer((_) => Stream.value([]));
  });

  testWidgets('Feedback tile uses correct email address', (tester) async {
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

    final feedbackTile = find.text('Feedback & Support');
    await tester.dragUntilVisible(
      feedbackTile,
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.tap(feedbackTile);
    await tester.pumpAndSettle();

    expect(mockUrlLauncher.url, contains('twangdeveloper@gmail.com'));
    expect(mockUrlLauncher.url, contains('mailto:'));
    expect(mockUrlLauncher.url, contains('subject=Attendance%20Tracker%20Feedback'));
  });
}
