import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_tracker/core/design/app_theme.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/hub/presentation/hub_page.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';

import 'helpers/mocks.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildTestSubject({
    required ThemeController themeController,
    required ThemeMode themeMode,
    required MockEventRepository eventRepo,
    required MockSessionRepository sessionRepo,
    required MockAttendanceRepository attendanceRepo,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      home: TickerMode(
        enabled: false,
        child: HubPage(
          themeController: themeController,
          sessionRepository: sessionRepo,
          eventRepository: eventRepo,
          attendanceRepository: attendanceRepo,
          disableAnimations: true,
        ),
      ),
    );
  }

  Future<void> pumpHubPage(
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

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final themeController = ThemeController(prefs);
    await themeController.updateThemeMode(themeMode);

    final eventRepo = MockEventRepository();
    final sessionRepo = MockSessionRepository();
    final attendanceRepo = MockAttendanceRepository();

    final now = DateTime.now();
    final todayWeekday = DateFormat('EEEE').format(now);
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowWeekday = DateFormat('EEEE').format(tomorrow);

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

    await tester.pumpWidget(
      buildTestSubject(
        themeController: themeController,
        themeMode: themeMode,
        eventRepo: eventRepo,
        sessionRepo: sessionRepo,
        attendanceRepo: attendanceRepo,
      ),
    );

    attendanceRepo.setFamilies([family]);
    sessionRepo.setSessions([session]);
    eventRepo.emit([todayEvent, upcomingEvent]);

    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
  }

  group('Headless Usability & Golden Matrix Audit', () {
    testWidgets('phone_light: 390x844 @ 1.0x light theme', (tester) async {
      await pumpHubPage(
        tester,
        themeMode: ThemeMode.light,
        size: const Size(390, 844),
        textScale: 1.0,
      );

      // Verify zero RenderFlex overflows
      expect(tester.takeException(), isNull);

      // Golden verification when --update-goldens is passed
      if (autoUpdateGoldenFiles) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/phone_light.png'),
        );
      }

      // Usability and Accessibility Guidelines
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('phone_dark: 390x844 @ 1.0x dark theme', (tester) async {
      await pumpHubPage(
        tester,
        themeMode: ThemeMode.dark,
        size: const Size(390, 844),
        textScale: 1.0,
      );

      // Verify zero RenderFlex overflows
      expect(tester.takeException(), isNull);

      // Golden verification when --update-goldens is passed
      if (autoUpdateGoldenFiles) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/phone_dark.png'),
        );
      }

      // Usability and Accessibility Guidelines
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });

    testWidgets('small_large_font: 320x568 @ 1.6x font scale', (tester) async {
      await pumpHubPage(
        tester,
        themeMode: ThemeMode.light,
        size: const Size(320, 568),
        textScale: 1.6,
      );

      // Verify zero RenderFlex overflows
      expect(tester.takeException(), isNull);

      // Golden verification when --update-goldens is passed
      if (autoUpdateGoldenFiles) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/small_large_font.png'),
        );
      }

      // Usability and Accessibility Guidelines
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });
}
