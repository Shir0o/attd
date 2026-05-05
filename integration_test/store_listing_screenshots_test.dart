import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'robots/attendance_robot.dart';
import 'robots/event_robot.dart';
import 'robots/history_robot.dart';
import 'robots/hub_robot.dart';
import 'robots/members_robot.dart';
import 'robots/settings_robot.dart';
import 'utils/test_utils.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Store listing screenshots', () {
    testWidgets('captures Play Store and App Store listing flows',
        (tester) async {
      final tempDir =
          await Directory.systemTemp.createTemp('attendance_store_listing_');
      final app = await createTestApp(tempDir);

      await tester.pumpWidget(app);
      await setupScreenshots(binding);
      await tester.pump(const Duration(milliseconds: 500));

      final hub = HubRobot(tester);
      final event = EventRobot(tester);
      final members = MembersRobot(tester);
      final attendance = AttendanceRobot(tester);
      final history = HistoryRobot(tester);
      final settings = SettingsRobot(tester);

      Future<void> capture(String name) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 500));

        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        final playStoreBytes = await binding
            .takeScreenshot('play_store_$name')
            .timeout(const Duration(seconds: 20));
        expect(playStoreBytes, isNotEmpty);

        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        final appStoreBytes = await binding
            .takeScreenshot('app_store_$name')
            .timeout(const Duration(seconds: 20));
        expect(appStoreBytes, isNotEmpty);
      }

      await tester.pumpUntilFound(find.text('Skip'));
      await capture('01_onboarding_quick_marking');

      if (find.byType(PageView).evaluate().isNotEmpty) {
        await tester.drag(find.byType(PageView), const Offset(-500, 0));
        await tester.pump(const Duration(milliseconds: 800));
        await capture('02_onboarding_session_history');
      }

      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(milliseconds: 1000));

      await tester.pumpUntilFound(find.text('No events scheduled'));
      await capture('03_empty_hub');

      await hub.tapFab();
      await tester.pump(const Duration(milliseconds: 800));
      await capture('04_new_event_blank');

      await event.enterName('Youth Group Attendance');
      await tester.pump(const Duration(milliseconds: 500));
      await capture('05_new_event_ready');

      await event.save();
      await tester.pump(const Duration(milliseconds: 1000));
      await hub.verifyOnHubPage();
      await hub.verifyEventCard('Youth Group Attendance');
      await capture('06_hub_with_event');

      await hub.tapEventMenu('Youth Group Attendance');
      await hub.selectMenuOption('Manage Members');
      await tester.pump(const Duration(milliseconds: 1000));
      await members.addMember('Alex Rivera');
      await members.addMember('Jordan Lee');
      await members.addMember('Taylor Kim');
      await members.addMember('Morgan Patel');
      await capture('07_manage_members_roster');

      await members.search('Alex');
      await tester.pump(const Duration(milliseconds: 500));
      await capture('08_member_search');
      await members.clearSearch();

      await hub.goBack();
      await tester.pump(const Duration(milliseconds: 1000));
      await hub.verifyOnHubPage();

      await hub.tapEventCard('Youth Group Attendance');
      await tester.pump(const Duration(milliseconds: 1500));
      await attendance.verifyCardName('Alex Rivera');
      await capture('09_attendance_deck_first_card');

      await attendance.swipePresent();
      await attendance.verifyCardName('Jordan Lee');
      await capture('10_attendance_deck_next_card');

      await attendance.swipeAbsent();
      await attendance.verifyCardName('Taylor Kim');
      await attendance.swipePresent();
      await attendance.verifyCardName('Morgan Patel');
      await attendance.swipePresent();
      await attendance.verifyDeckComplete();
      await capture('11_attendance_complete');

      await attendance.finishSession();
      await tester.pump(const Duration(milliseconds: 1000));
      await history.verifySummaryCounts(present: 3, absent: 1);
      await capture('12_session_summary');

      await hub.goBack();
      await tester.pump(const Duration(milliseconds: 1000));
      await hub.verifyOnHubPage();
      await hub.verifyEventStatus('Youth Group Attendance', 'Taken');
      await capture('13_hub_after_session');

      await hub.tapSettings();
      await settings.verifyOnSettingsPage();
      await capture('14_settings_light');

      await settings.toggleTheme();
      await settings.verifyDarkTheme();
      await capture('15_settings_dark');
    });
  });
}
