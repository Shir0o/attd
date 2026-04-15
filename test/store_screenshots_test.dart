import 'package:attendance_tracker/core/design/app_colors.dart';
import 'package:attendance_tracker/core/design/app_theme.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/hub/presentation/hub_page.dart';
import 'package:attendance_tracker/features/onboarding/application/onboarding_controller.dart';
import 'package:attendance_tracker/features/onboarding/presentation/onboarding_page.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:attendance_tracker/features/settings/presentation/settings_page.dart';
import 'package:attendance_tracker/features/attendance/presentation/attendance_deck_page.dart';
import 'package:attendance_tracker/features/attendance/presentation/session_summary_page.dart';
import 'package:attendance_tracker/features/settings/data/drive_service.dart';
import 'package:attendance_tracker/features/settings/data/local_backup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_screenshot/golden_screenshot.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'helpers/mocks.dart';

class MockThemeController extends Mock implements ThemeController {}
class MockOnboardingController extends Mock implements OnboardingController {}
class MockDriveService extends Mock implements DriveService {}
class MockLocalBackupService extends Mock implements LocalBackupService {}

void main() {
  late MockAttendanceRepository attendanceRepository;
  late MockEventRepository eventRepository;
  late MockSessionRepository sessionRepository;
  late MockThemeController themeController;
  late MockOnboardingController onboardingController;
  late MockDriveService driveService;
  late MockLocalBackupService localBackupService;
  late SharedPreferences prefs;

  setUpAll(() {
    registerFallbackValue(ThemeMode.light);
    // Disable runtime fetching for Google Fonts in tests
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    attendanceRepository = MockAttendanceRepository();
    eventRepository = MockEventRepository();
    sessionRepository = MockSessionRepository();
    themeController = MockThemeController();
    onboardingController = MockOnboardingController();
    driveService = MockDriveService();
    localBackupService = MockLocalBackupService();
    
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    when(() => themeController.themeMode).thenReturn(ThemeMode.light);
    when(() => themeController.addListener(any())).thenAnswer((_) {});
    when(() => themeController.removeListener(any())).thenAnswer((_) {});

    when(() => onboardingController.shouldShowOnboarding).thenReturn(false);
    when(() => onboardingController.addListener(any())).thenAnswer((_) {});
    when(() => onboardingController.removeListener(any())).thenAnswer((_) {});

    when(() => driveService.isDriveSyncEnabled).thenReturn(false);
    when(() => driveService.isSyncing).thenReturn(false);
    when(() => driveService.addListener(any())).thenAnswer((_) {});
    when(() => driveService.removeListener(any())).thenAnswer((_) {});

    attendanceRepository.setFamilies([]);
    eventRepository.emit([]);
    sessionRepository.emit([]);
  });

  final devices = [
    GoldenScreenshotDevices.androidPhone.device,
    // Custom 7 inch tablet device
    const ScreenshotDevice(
      platform: TargetPlatform.android,
      resolution: Size(1200, 1920),
      pixelRatio: 2.0,
      goldenSubFolder: 'sevenInchScreenshots/',
      frameBuilder: ScreenshotFrame.androidTablet,
    ),
    GoldenScreenshotDevices.androidTablet.device,
  ];

  Future<void> takeScreenshots(
    WidgetTester tester,
    String name,
    Widget home, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    // Create a clean theme without GoogleFonts for tests
    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: AppColors.lightColorScheme,
      scaffoldBackgroundColor: AppColors.lightColorScheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.lightColorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: AppColors.darkColorScheme,
      scaffoldBackgroundColor: AppColors.darkColorScheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.darkColorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );

    for (final device in devices) {
      await tester.pumpWidget(
        ScreenshotApp(
          device: device,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          home: home,
        ),
      );
      // Using pump with fixed durations instead of pumpAndSettle to avoid infinite animation timeouts (like shimmers)
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.expectScreenshot(device, name);
    }
  }

  group('Store Screenshots', () {
    testGoldens('01_onboarding', (tester) async {
      await takeScreenshots(
        tester,
        '01_onboarding',
        OnboardingPage(onboardingController: onboardingController),
      );
    });

    testGoldens('02_hub_empty', (tester) async {
      await takeScreenshots(
        tester,
        '02_hub_empty',
        HubPage(
          themeController: themeController,
          sessionRepository: sessionRepository,
          eventRepository: eventRepository,
          attendanceRepository: attendanceRepository,
          driveService: driveService,
          localBackupService: localBackupService,
        ),
      );
    });

    testGoldens('03_hub_with_data', (tester) async {
      final sampleEvent = Event(
        id: '1',
        title: 'Weekly Sync',
        frequency: 'Weekly',
        repeatingDays: const ['Monday'],
        time: const TimeOfDay(hour: 10, minute: 0),
        memberIds: const ['m1', 'm2'],
        createdAt: DateTime.now(),
      );
      
      final sampleFamilies = [
        Family(
          id: 'f1',
          displayName: 'Team A',
          members: [
            Member(id: 'm1', displayName: 'Alice Smith'),
            Member(id: 'm2', displayName: 'Bob Jones'),
          ],
        ),
      ];

      eventRepository.emit([sampleEvent]);
      attendanceRepository.setFamilies(sampleFamilies);
      
      await takeScreenshots(
        tester,
        '03_hub_with_data',
        HubPage(
          themeController: themeController,
          sessionRepository: sessionRepository,
          eventRepository: eventRepository,
          attendanceRepository: attendanceRepository,
          driveService: driveService,
          localBackupService: localBackupService,
        ),
      );
    });

    testGoldens('04_attendance_taking', (tester) async {
      final sampleEvent = Event(
        id: '1',
        title: 'Weekly Sync',
        frequency: 'Weekly',
        repeatingDays: const ['Monday'],
        time: const TimeOfDay(hour: 10, minute: 0),
        memberIds: const ['m1', 'm2'],
        createdAt: DateTime.now(),
      );
      
      final sampleMembers = [
        Member(id: 'm1', displayName: 'Alice Smith'),
        Member(id: 'm2', displayName: 'Bob Jones'),
      ];

      final sampleSession = Session(
        id: 's1',
        eventId: '1',
        title: 'Weekly Sync',
        sessionDate: DateTime.now(),
        records: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'tester',
        currentVersion: 1,
      );

      await takeScreenshots(
        tester,
        '04_attendance_taking',
        AttendanceDeckPage(
          session: sampleSession,
          members: sampleMembers,
          attendanceRepository: attendanceRepository,
          sessionRepository: sessionRepository,
          eventRepository: eventRepository,
          driveService: driveService,
        ),
      );
    });

    testGoldens('05_session_summary', (tester) async {
      final sampleSession = Session(
        id: 's1',
        title: 'Weekly Sync',
        sessionDate: DateTime.now(),
        records: [
          SessionRecord(
            memberId: 'm1', 
            attendee: 'Alice Smith',
            status: AttendanceStatus.present,
            recordedAt: DateTime.now(),
            recordedBy: 'tester',
          ),
          SessionRecord(
            memberId: 'm2', 
            attendee: 'Bob Jones',
            status: AttendanceStatus.absent,
            recordedAt: DateTime.now(),
            recordedBy: 'tester',
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'tester',
        currentVersion: 1,
      );

      sessionRepository.emit([sampleSession]);
      
      await takeScreenshots(
        tester,
        '05_session_summary',
        SessionSummaryPage(
          session: sampleSession,
          members: const [], 
          sessionRepository: sessionRepository,
          attendanceRepository: attendanceRepository,
        ),
      );
    });

    testGoldens('06_settings', (tester) async {
      await takeScreenshots(
        tester,
        '06_settings',
        SettingsPage(
          themeController: themeController,
          attendanceRepository: attendanceRepository,
          sessionRepository: sessionRepository,
          eventRepository: eventRepository,
          driveService: driveService,
          localBackupService: localBackupService,
        ),
      );
    });

    testGoldens('07_hub_dark', (tester) async {
      when(() => themeController.themeMode).thenReturn(ThemeMode.dark);
      
      final sampleEvent = Event(
        id: '1',
        title: 'Night Shift',
        frequency: 'Daily',
        time: const TimeOfDay(hour: 22, minute: 0),
        createdAt: DateTime.now(),
      );

      eventRepository.emit([sampleEvent]);

      await takeScreenshots(
        tester,
        '07_hub_dark',
        HubPage(
          themeController: themeController,
          sessionRepository: sessionRepository,
          eventRepository: eventRepository,
          attendanceRepository: attendanceRepository,
          driveService: driveService,
          localBackupService: localBackupService,
        ),
        themeMode: ThemeMode.dark,
      );
    });
  });
}
