import 'dart:io';

import 'package:attendance_tracker/core/design/app_theme.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/onboarding/application/onboarding_controller.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:attendance_tracker/features/settings/data/drive_service.dart';
import 'package:attendance_tracker/features/settings/data/local_backup_service.dart';
import 'package:attendance_tracker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/mocks.dart';

/// Minimal [DriveService] stand-in for UI audits. The Hub always passes a
/// non-null DriveService to Settings, but the surfaces exercised here only read
/// connection/background-sync state, so no native plugin calls are needed.
class _FakeDriveService extends ChangeNotifier implements DriveService {
  @override
  bool isSyncing = false;

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
  Future<void> init() async {}

  @override
  drive.DriveApi? get driveApi => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Widget tests do not load Material icons by default, so every Icon would
    // otherwise render as a tofu box in generated goldens. Fidelity only: on a
    // runner that does not expose the framework font, keep auditing anyway.
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      final iconFont = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await iconFont.load();
    } catch (_) {
      // Goldens may show tofu icons; layout, tap targets and contrast are
      // unaffected.
    }
  });

  // AttendanceApp registers launcher quick actions on start-up. Widget tests
  // have no plugin host, so answer the channel locally instead of letting an
  // unhandled MissingPluginException fail the audit.
  const quickActionsChannel = MethodChannel('plugins.flutter.io/quick_actions');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(quickActionsChannel, (call) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(quickActionsChannel, null);
  });

  /// Pumps the real app shell ([AttendanceApp]) with seeded repositories so the
  /// audit covers the Hub, Settings, navigation and modal surfaces that ship.
  Future<void> pumpMainApp(
    WidgetTester tester, {
    required ThemeMode themeMode,
    required Size size,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    final prefs = await SharedPreferences.getInstance();
    final themeController = ThemeController(prefs);
    await themeController.updateThemeMode(themeMode);
    final onboardingController = OnboardingController(prefs);

    final eventRepo = MockEventRepository();
    final sessionRepo = MockSessionRepository();
    final attendanceRepo = MockAttendanceRepository();
    final driveService = _FakeDriveService();
    final localBackupService = LocalBackupService(
      documentsDirectoryProvider: () async => Directory.systemTemp,
    );

    final now = DateTime.now();
    final todayWeekday = DateFormat('EEEE').format(now);
    final tomorrowWeekday = DateFormat(
      'EEEE',
    ).format(now.add(const Duration(days: 1)));

    final todayEvent = Event(
      id: 'event-today',
      title: 'Weekly Standup',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'Weekly',
      repeatingDays: [todayWeekday],
      memberIds: ['m1', 'm2'],
      createdAt: now,
    );

    final upcomingEvent = Event(
      id: 'event-upcoming',
      title: 'Design Review & Planning',
      time: const TimeOfDay(hour: 14, minute: 30),
      frequency: 'Weekly',
      repeatingDays: [tomorrowWeekday],
      memberIds: ['m1'],
      createdAt: now,
    );

    final family = Family(
      id: 'f1',
      displayName: 'Smith Family',
      members: [
        Member(id: 'm1', displayName: 'Alice Smith'),
        Member(id: 'm2', displayName: 'Bob Smith'),
      ],
    );

    final session = Session(
      id: 's1',
      eventId: 'event-today',
      title: 'Weekly Standup',
      sessionDate: now,
      records: [
        SessionRecord(
          attendee: 'm1',
          status: AttendanceStatus.present,
          recordedAt: now,
          recordedBy: 'User',
        ),
      ],
      createdAt: now,
      updatedAt: now,
      createdBy: 'User',
      currentVersion: 1,
    );

    // Resolve the bundled Google Fonts before the first frame. The static app
    // bar text never rebuilds, so without this warm-up it would stay in the
    // test fallback font and goldens would show tofu boxes.
    AppTheme.lightTheme();
    AppTheme.darkTheme();
    await GoogleFonts.pendingFonts();

    await tester.pumpWidget(
      AttendanceApp(
        themeController: themeController,
        onboardingController: onboardingController,
        repository: attendanceRepo,
        sessionRepository: sessionRepo,
        eventRepository: eventRepo,
        driveService: driveService,
        localBackupService: localBackupService,
        prefs: prefs,
        disableAnimations: true,
      ),
    );

    attendanceRepo.setFamilies([family]);
    sessionRepo.setSessions([session]);
    eventRepo.emit([todayEvent, upcomingEvent]);

    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
  }

  /// Asserts the three audit lenses at the current screen: no framework
  /// exception (RenderFlex overflow included), Android tap targets, and WCAG
  /// text contrast.
  Future<void> expectUsable(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  /// Goldens are only written/compared when the suite runs with
  /// `--update-goldens`; a normal CI run never needs checked-in pixels.
  Future<void> maybeExpectGolden(WidgetTester tester, String name) async {
    if (!autoUpdateGoldenFiles) return;
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  group('Headless usability & golden matrix audit', () {
    testWidgets('phone_light: 390x844 @ 1.0x light theme', (tester) async {
      await pumpMainApp(
        tester,
        themeMode: ThemeMode.light,
        size: const Size(390, 844),
      );

      expect(find.text('Today'), findsOneWidget);
      await expectUsable(tester);
      await maybeExpectGolden(tester, 'phone_light');
    });

    testWidgets('phone_dark: 390x844 @ 1.0x dark theme', (tester) async {
      await pumpMainApp(
        tester,
        themeMode: ThemeMode.dark,
        size: const Size(390, 844),
      );

      expect(find.text('Today'), findsOneWidget);
      await expectUsable(tester);
      await maybeExpectGolden(tester, 'phone_dark');
    });

    testWidgets('small_large_font: 320x568 @ 1.6x font scale', (tester) async {
      await pumpMainApp(
        tester,
        themeMode: ThemeMode.light,
        size: const Size(320, 568),
        textScale: 1.6,
      );

      expect(find.text('Today'), findsOneWidget);
      await expectUsable(tester);
      await maybeExpectGolden(tester, 'small_large_font');
    });

    testWidgets('interactive_click_through: primary navigation and dialogs', (
      tester,
    ) async {
      await pumpMainApp(
        tester,
        themeMode: ThemeMode.light,
        size: const Size(390, 844),
      );

      // ── Hub → Settings ────────────────────────────────────────────────
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsWidgets);
      // Settings section eyebrows, member/family labels and the add-event form
      // all use the ink3 token, which now clears WCAG AA on every light surface.
      await expectUsable(tester);
      await maybeExpectGolden(tester, 'step_settings');

      // ── Settings → Manage Members ─────────────────────────────────────
      final membersTile = find.byKey(const ValueKey('manage_members_tile'));
      await tester.scrollUntilVisible(
        membersTile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(membersTile);
      await tester.pumpAndSettle();
      expect(find.text('Manage Members'), findsWidgets);
      await expectUsable(tester);
      await maybeExpectGolden(tester, 'step_manage_members');

      // Back to Settings.
      await tester.pageBack();
      await tester.pumpAndSettle();

      // ── Settings → Manage Families ────────────────────────────────────
      final familiesTile = find.byKey(const ValueKey('manage_families_tile'));
      await tester.scrollUntilVisible(
        familiesTile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(familiesTile);
      await tester.pumpAndSettle();
      expect(find.text('Manage Families'), findsWidgets);
      await expectUsable(tester);
      await maybeExpectGolden(tester, 'step_manage_families');

      // Back to Settings, then back to the Hub.
      await tester.pageBack();
      await tester.pumpAndSettle();
      // Settings uses a custom arrow-back leading widget, so pageBack() cannot
      // find it.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);
      await expectUsable(tester);

      // ── Hub → event options sheet → Fast Marking Mode dialog ──────────
      final eventMenu = find.byTooltip('Event options').first;
      await tester.tap(eventMenu);
      await tester.pumpAndSettle();
      expect(find.text('Fast Marking Mode'), findsOneWidget);
      // The destructive "Delete Event" row uses `context.conv.danger`.
      await expectUsable(tester);
      await maybeExpectGolden(tester, 'step_event_options_sheet');

      await tester.tap(find.byKey(const Key('eventMenuFastMarkingMode')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Choose the fast marking surface shown alongside Deck and List during attendance.',
        ),
        findsOneWidget,
      );
      await expectUsable(tester);
      await maybeExpectGolden(tester, 'step_fast_marking_mode_sheet');

      // Save closes the sheet without changing the seeded event.
      await tester.tap(find.byKey(const Key('markingModeConfirmButton')));
      await tester.pumpAndSettle();
      expect(find.text('Today'), findsOneWidget);

      // ── Hub → New event (FAB) ─────────────────────────────────────────
      await tester.tap(find.byKey(const ValueKey('hub_fab')));
      await tester.pumpAndSettle();
      // ConvEyebrow upper-cases its label.
      expect(find.text('NEW EVENT'), findsOneWidget);
      await expectUsable(tester);
      await maybeExpectGolden(tester, 'step_add_event');
    });
  });
}
