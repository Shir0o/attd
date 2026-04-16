import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'utils/test_utils.dart';
import 'robots/hub_robot.dart';
import 'robots/event_robot.dart';
import 'robots/members_robot.dart';
import 'robots/attendance_robot.dart';
import 'robots/history_robot.dart';
import 'robots/settings_robot.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Attendance App Integration Tests', () {
    // Accessing environment variables from .env via --dart-define-from-file
    // Note: The keys must match exactly what is in your .env file
    const projectNumber = String.fromEnvironment('GOOGLE_CLOUD_PROJECT_NUMBER',
        defaultValue: 'unknown');
    const isTest = bool.fromEnvironment('IS_TEST_MODE');

    testWidgets('Full System Scenario', (tester) async {
      print('DEBUG: Running test for Project Number: $projectNumber');
      print('DEBUG: Test Mode Enabled: $isTest');

      // 1. Initial State: User downloads app and opens for the first time (no existing data)
      final tempDir =
          await Directory.systemTemp.createTemp('attendance_full_scenario_');
      final app = await createTestApp(tempDir);

      print('--- Starting Test ---');
      await tester.pumpWidget(app);
      await setupScreenshots(binding);
      await tester.pump(const Duration(milliseconds: 500));

      final hub = HubRobot(tester);
      final event = EventRobot(tester);
      final members = MembersRobot(tester);
      final attendance = AttendanceRobot(tester);
      final history = HistoryRobot(tester);
      final settings = SettingsRobot(tester);

      // 1. Skip the onboarding tutorial
      print('DEBUG: Step 1 - Skip onboarding tutorial');
      await tester.pumpUntilFound(find.text('Skip'));
      await tester.takeScreenshot(binding, '01_onboarding_tutorial_start');
      
      // Explore onboarding steps a bit more
      if (find.text('Next').evaluate().isNotEmpty) {
        await tester.tap(find.text('Next'));
        await tester.pump(const Duration(milliseconds: 1000));
        await tester.takeScreenshot(binding, '01b_onboarding_tutorial_step2');
      }

      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(milliseconds: 1000));

      print('DEBUG: Step 1a - Verify empty hub');
      await tester.pumpUntilFound(find.text('No events scheduled'));
      await tester.takeScreenshot(binding, '02_empty_hub');

      // 2. User adds a new event
      print('DEBUG: Step 2 - Add new event');
      await hub.tapFab();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.takeScreenshot(binding, '02b_add_event_initial');

      print('DEBUG: Step 2a - Enter event name');
      await event.enterName('Original Event');

      print('DEBUG: Step 2b - Select frequency');
      // Use Daily to ensure it is "Today"
      await event.selectFrequency('Weekly');
      await tester.takeScreenshot(binding, '02c_add_event_frequency_selection');

      // Actually daily is better for tests but we have specific robot for day selection
      // Let's use Weekly and select CURRENT day.
      final currentDay = [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday'
      ][DateTime.now().weekday % 7];

      print('DEBUG: Step 2c - Select day ($currentDay)');
      await event.selectDay(currentDay);
      await tester.takeScreenshot(binding, '02d_add_event_day_selected');

      print('DEBUG: Step 2d - Select time (10:00)');
      await event.selectTime(10, 0);
      await tester.takeScreenshot(binding, '03_create_event_form');

      print('DEBUG: Step 2e - Save event');
      await event.save();
      await tester.pump(const Duration(milliseconds: 1000));

      // 3. User goes back to home and sees the event
      print('DEBUG: Step 3 - Verify event on hub');
      await hub.verifyOnHubPage();
      await hub.verifyEventCard('Original Event');
      await tester.takeScreenshot(binding, '04_hub_with_event');

      // 4. User edits the event
      print('DEBUG: Step 4 - Edit event');
      await hub.tapEventMenu('Original Event');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.takeScreenshot(binding, '05_event_context_menu');
      await hub.selectMenuOption('Edit Event');

      await tester.pump(const Duration(milliseconds: 800));
      await event.enterName('Updated Event');
      // Keep weekly + current day
      await tester.takeScreenshot(binding, '06_edit_event_form');

      print('DEBUG: Step 4a - Update event');
      await event.update();
      await tester.pump(const Duration(milliseconds: 1000));
      await hub.verifyOnHubPage();
      await hub.verifyEventCard('Updated Event');
      await tester.takeScreenshot(binding, '07_hub_after_edit');

      // 5. User manages members
      print('DEBUG: Step 5 - Manage members');
      await hub.tapEventMenu('Updated Event');
      await hub.selectMenuOption('Manage Members');

      await tester.pump(const Duration(milliseconds: 1000));
      await members.addMember('Alice');
      await members.addMember('Bob');
      await members.addMember('Charlie');
      await tester.takeScreenshot(binding, '08_manage_members');

      print('DEBUG: Step 5a - Search members');
      await members.search('Ali');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.takeScreenshot(binding, '09_member_search');
      await members.clearSearch();

      print('DEBUG: Step 5b - Toggle members');
      await members.verifyMemberSelected('Alice', true);
      await members.toggleMember('Alice');
      await members.verifyMemberSelected('Alice', false);
      await tester.takeScreenshot(binding, '10_member_toggle_off');
      await members.toggleMember('Alice');
      await members.verifyMemberSelected('Alice', true);
      await tester.takeScreenshot(binding, '10b_member_toggle_back_on');

      // 6. User verifies member selections persist
      print('DEBUG: Step 6 - Verify member persistence');
      await hub.goBack();
      await tester.pump(const Duration(milliseconds: 1000));
      await hub.verifyOnHubPage();

      await hub.tapEventMenu('Updated Event');
      await hub.selectMenuOption('Manage Members');
      await tester.pump(const Duration(milliseconds: 1000));
      await members.verifyMemberSelected('Alice', true);
      await members.verifyMemberSelected('Bob', true);
      await members.verifyMemberSelected('Charlie', true);
      await tester.takeScreenshot(binding, '10c_manage_members_final');

      await hub.goBack();
      await tester.pump(const Duration(milliseconds: 1000));
      await hub.verifyOnHubPage();

      // 7. User starts attendance session
      print('DEBUG: Step 7 - Start attendance session');
      await hub.tapEventCard('Updated Event');
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.takeScreenshot(binding, '10d_attendance_deck_start');

      // 8. User completes the session
      print('DEBUG: Step 8 - Complete session');
      // All 3 members should be in the deck
      await attendance.verifyCardName('Alice');
      await tester.takeScreenshot(binding, '10e_attendance_deck_card_1');
      await attendance.swipePresent();

      await attendance.verifyCardName('Bob');
      await tester.takeScreenshot(binding, '10f_attendance_deck_card_2');
      await attendance.swipeAbsent();

      await attendance.verifyCardName('Charlie');
      await tester.takeScreenshot(binding, '10g_attendance_deck_card_3');
      await attendance.swipePresent();

      await attendance.verifyDeckComplete();
      await tester.takeScreenshot(binding, '11_deck_complete');

      await attendance.finishSession();
      await tester.pump(const Duration(milliseconds: 1000));

      // 9. User verifies summary
      print('DEBUG: Step 9 - Verify summary');
      await history.verifySummaryCounts(present: 2, absent: 1);
      await tester.takeScreenshot(binding, '12_session_summary');

      await hub.goBack();
      await tester.pump(const Duration(milliseconds: 1000));
      await hub.verifyOnHubPage();

      // 10. User verifies event status updated on Hub
      print('DEBUG: Step 10 - Verify hub status');
      await hub.verifyEventStatus('Updated Event', 'Taken');
      await tester.takeScreenshot(binding, '13_hub_with_status');

      // 11. User views history
      print('DEBUG: Step 11 - View history');
      await hub.tapEventMenu('Updated Event');
      await hub.selectMenuOption('View History');
      await tester.pump(const Duration(milliseconds: 1000));

      await history.verifySessionCount(1);
      await tester.takeScreenshot(binding, '14_event_history');

      // 12. User deletes session
      print('DEBUG: Step 12 - Delete session');
      await history.tapSession(0);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.takeScreenshot(binding, '14b_session_detail_from_history');
      await history.deleteSession();
      await history.verifySessionCount(0);
      await tester.takeScreenshot(binding, '14c_event_history_empty_after_delete');

      await hub.goBack();
      await tester.pump(const Duration(milliseconds: 1000));
      await hub.verifyOnHubPage();
      await hub.verifyEventStatus('Updated Event', 'Start');

      // 13. User settings and theme
      print('DEBUG: Step 13 - Settings');
      await hub.tapSettings();
      await settings.verifyOnSettingsPage();
      await tester.takeScreenshot(binding, '15_settings_page');

      await settings.toggleTheme();
      await settings.verifyDarkTheme();
      await tester.takeScreenshot(binding, '16_settings_dark');

      await hub.goBack();
      await tester.pump(const Duration(milliseconds: 1000));
      await hub.verifyOnHubPage();
      await tester.takeScreenshot(binding, '17_hub_dark_mode');

      print('--- Test Completed Successfully ---');
    });
  });
}
