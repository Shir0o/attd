import 'dart:io';
import 'package:flutter/material.dart';
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
    const projectNumber = String.fromEnvironment('GOOGLE_CLOUD_PROJECT_NUMBER', defaultValue: 'unknown');
    const isTest = bool.fromEnvironment('IS_TEST_MODE');

    testWidgets('Full System Scenario', (tester) async {
      print('DEBUG: Running test for Project Number: $projectNumber');
      print('DEBUG: Test Mode Enabled: $isTest');

      // 1. Initial State: User downloads app and opens for the first time (no existing data)
      final tempDir = await Directory.systemTemp.createTemp('attendance_full_scenario_');
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
      await tester.takeScreenshot(binding, '01_onboarding_tutorial');
      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(milliseconds: 500));

      print('DEBUG: Step 1a - Verify empty hub');
      await tester.pumpUntilFound(find.text('No events created yet'));
      await tester.takeScreenshot(binding, '02_empty_hub');

      // 2. User adds a new event
      print('DEBUG: Step 2 - Add new event');
      await hub.tapFab();
      await tester.takeScreenshot(binding, '02b_add_event_initial');

      print('DEBUG: Step 2a - Enter event name');
      await event.enterName('Original Event');

      print('DEBUG: Step 2b - Select frequency');
      await event.selectFrequency('Monthly');
      print('DEBUG: Step 2c - Select day');
      await event.selectDay('Monday');
      await tester.takeScreenshot(binding, '03_create_event_form');

      print('DEBUG: Step 2d - Save event');
      await event.save();
      await tester.pump(const Duration(milliseconds: 800));

      // 3. User goes back to home and sees the event
      print('DEBUG: Step 3 - Verify event on hub');
      await hub.verifyOnHubPage();
      await hub.verifyEventCard('Original Event');
      await tester.takeScreenshot(binding, '04_hub_with_event');

      // 4. User edits the event
      print('DEBUG: Step 4 - Edit event');
      await hub.tapEventMenu('Original Event');
      await tester.takeScreenshot(binding, '05_event_context_menu');
      await hub.selectMenuOption('Edit Event');
      
      await event.enterName('Updated Event');
      await event.selectFrequency('Weekly');
      await event.selectDay('Monday');
      await tester.takeScreenshot(binding, '06_edit_event_form');
      
      print('DEBUG: Step 4a - Update event');
      await event.update();
      await tester.pump(const Duration(milliseconds: 800));
      await hub.verifyOnHubPage();
      await hub.verifyEventCard('Updated Event');
      await tester.takeScreenshot(binding, '07_hub_after_edit');

      // 5. User manages members
      print('DEBUG: Step 5 - Manage members');
      await hub.tapEventMenu('Updated Event');
      await hub.selectMenuOption('Manage Members');
      
      await members.addMember('Alice');
      await members.addMember('Bob');
      await members.addMember('Charlie');
      await tester.takeScreenshot(binding, '08_manage_members');
      
      // User searches for members
      print('DEBUG: Step 5a - Search members');
      await members.search('Ali');
      await tester.pumpUntilAbsent(find.text('Bob'));
      expect(find.text('Alice'), findsOneWidget);
      await tester.takeScreenshot(binding, '09_member_search');
      await members.clearSearch();
      
      // User checks/unchecks member
      print('DEBUG: Step 5b - Toggle members');
      await members.verifyMemberSelected('Alice', true);
      await members.toggleMember('Alice');
      await members.verifyMemberSelected('Alice', false);
      await tester.takeScreenshot(binding, '10_member_toggle_off');
      await members.toggleMember('Alice');
      await members.verifyMemberSelected('Alice', true);

      // 6. User verifies member selections persist
      print('DEBUG: Step 6 - Verify member persistence');
      await hub.goBack();
      await hub.verifyOnHubPage();
      
      await hub.tapEventMenu('Updated Event');
      await hub.selectMenuOption('Manage Members');
      await members.verifyMemberSelected('Alice', true);
      await members.verifyMemberSelected('Bob', true);
      await members.verifyMemberSelected('Charlie', true);
      
      await hub.goBack();

      // 7. User starts attendance session
      print('DEBUG: Step 7 - Start attendance session');
      await hub.tapEventCard('Updated Event');
      await tester.pump(const Duration(milliseconds: 500));
      
      // 8. User completes the session
      print('DEBUG: Step 8 - Complete session');
      await tester.pumpUntilFound(find.text('Alice'));
      await tester.takeScreenshot(binding, '11_attendance_card_alice');
      await attendance.markPresent(); // Alice
      await tester.takeScreenshot(binding, '12_attendance_card_bob');
      await attendance.markAbsent();  // Bob
      await tester.takeScreenshot(binding, '13_attendance_card_charlie');
      await attendance.markPresent(); // Charlie
      
      // 9. User sees session summary
      print('DEBUG: Step 9 - Verify session summary');
      await attendance.verifyDeckComplete();
      await tester.takeScreenshot(binding, '14_session_complete');

      // 10. User finalizes report
      print('DEBUG: Step 10 - Finalize report');
      await attendance.finishSession();
      await hub.verifyOnHubPage();
      await hub.verifyEventStatus('Updated Event', 'COMPLETED');
      await tester.takeScreenshot(binding, '15_hub_completed_status');

      // 11. User views history
      print('DEBUG: Step 11 - View history');
      await hub.tapEventMenu('Updated Event');
      await hub.selectMenuOption('View History');
      
      await history.verifySessionCount(1);
      await tester.takeScreenshot(binding, '16_history_list');
      
      await history.tapSession(0);
      await history.verifySummaryCounts(present: 2, absent: 1);
      await tester.takeScreenshot(binding, '17_session_detail');

      // 12. User deletes the session
      print('DEBUG: Step 12 - Delete session');
      await history.deleteSession();
      await history.verifySessionCount(0);
      await tester.takeScreenshot(binding, '18_history_empty');
      
      // 13. User goes back home
      print('DEBUG: Step 13 - Back to start');
      await hub.goBack();
      await hub.verifyOnHubPage();
      await hub.verifyEventStatus('Updated Event', 'START');
      await tester.takeScreenshot(binding, '19_hub_reset_status');

      // 14. User adds another event
      print('DEBUG: Step 14 - Add second event');
      await hub.tapFab();
      await event.enterName('Second Event');
      await tester.takeScreenshot(binding, '20_create_second_event');
      await event.save();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.takeScreenshot(binding, '21_hub_two_events');
      
      // 15. User verifies member isolation between events
      print('DEBUG: Step 15 - Verify member isolation');
      await hub.tapEventMenu('Second Event');
      await hub.selectMenuOption('Manage Members');
      
      await members.verifyMember('Alice');
      await members.verifyMember('Bob');
      await members.verifyMemberSelected('Alice', false);
      await members.verifyMemberSelected('Bob', false);
      await tester.takeScreenshot(binding, '22_member_isolation');

      // 16. User assigns members to second event
      print('DEBUG: Step 16 - Assign members');
      await members.toggleMember('Alice');
      await members.verifyMemberSelected('Alice', true);
      
      // 17. User verifies assignment persists
      print('DEBUG: Step 17 - Verify persistence');
      await hub.goBack();
      await hub.tapEventMenu('Second Event');
      await hub.selectMenuOption('Manage Members');
      await members.verifyMemberSelected('Alice', true);
      await members.verifyMemberSelected('Bob', false);
      
      await hub.goBack();

      // 18. User navigates to Settings
      print('DEBUG: Step 18 - Navigate to settings');
      await hub.tapSettings();
      await settings.verifyOnSettingsPage();
      await tester.takeScreenshot(binding, '23_settings_page');

      // 19. User opens Manage Backup Data
      print('DEBUG: Step 19 - Open Manage Backup Data');
      await settings.tapManageBackupData();
      await settings.verifyOnManageBackupDataPage();

      // Verify data: 2 events, 3 members, 0 sessions = 5 total records
      await settings.verifyRecordCount(5);
      await settings.verifyEventListed('Updated Event');
      await settings.verifyEventListed('Second Event');
      await settings.verifyMemberListed('Alice');
      await settings.verifyMemberListed('Bob');
      await settings.verifyMemberListed('Charlie');
      await tester.takeScreenshot(binding, '24_manage_backup_data');

      // Go back to hub
      await hub.goBack(); // Back to Settings
      await hub.goBack(); // Back to Hub
      await hub.verifyOnHubPage();

      // Cleanup
      print('DEBUG: Test complete!');
      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });
  });
}
