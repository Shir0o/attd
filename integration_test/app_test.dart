import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'utils/test_utils.dart';
import 'robots/hub_robot.dart';
import 'robots/event_robot.dart';
import 'robots/members_robot.dart';
import 'robots/attendance_robot.dart';
import 'robots/history_robot.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Attendance App Integration Tests', () {
    testWidgets('Full System Scenario', (tester) async {
      await binding.convertFlutterSurfaceToImage();

      // 1. Initial State: User downloads app and opens for the first time (no existing data)
      final tempDir = await Directory.systemTemp.createTemp('attendance_full_scenario_');
      final app = await createTestApp(tempDir);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final hub = HubRobot(tester);
      final event = EventRobot(tester);
      final members = MembersRobot(tester);
      final attendance = AttendanceRobot(tester);
      final history = HistoryRobot(tester);

      // Verify empty state
      await tester.pumpUntilFound(find.text('No events created yet'));
      await tester.takeScreenshot(binding, 'full_01_empty_hub');

      // 2. User adds a new event
      await hub.tapFab();
      await tester.takeScreenshot(binding, 'full_02_add_event_page');

      // User changes every field of that page
      await event.enterName('Original Event');
      await event.selectFrequency('Monthly');
      await event.selectDate(15);
      await event.selectTime(14, 30);
      
      await tester.takeScreenshot(binding, 'full_03_event_fields_changed');

      // User confirms creation
      await event.save();
      await tester.pumpAndSettle();

      // 3. User goes back to home and sees the event (with all expected ui features)
      await hub.verifyOnHubPage();
      await hub.verifyEventCard('Original Event');
      await tester.takeScreenshot(binding, 'full_04_hub_after_create');

      // 4. User clicks on the menu for that new event and edits the event (changing every field)
      await hub.tapEventMenu('Original Event');
      await hub.selectMenuOption('Edit Event');
      
      await event.enterName('Updated Event');
      await event.selectFrequency('Weekly');
      await event.selectDay('Monday');
      await event.selectTime(9, 0);
      
      await tester.takeScreenshot(binding, 'full_05_event_edited');

      // User confirms, goes back to home, and sees the updated according to changes made
      await event.update();
      await tester.pumpAndSettle();
      await hub.verifyOnHubPage();
      await hub.verifyEventCard('Updated Event');
      await tester.takeScreenshot(binding, 'full_06_hub_after_edit');

      // 5. User clicks on the menu and then goes into manage members
      await hub.tapEventMenu('Updated Event');
      await hub.selectMenuOption('Manage Members');
      
      // User adds member
      await members.addMember('Alice');
      await members.addMember('Bob');
      await members.addMember('Charlie');
      
      // User searches for members
      await members.search('Ali');
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsNothing);
      await members.clearSearch();
      
      // User checks/unchecks member (with validation logic after each action)
      // Alice and Bob should be checked by default because they were just added in event mode
      await members.verifyMemberSelected('Alice', true);
      await members.toggleMember('Alice');
      await members.verifyMemberSelected('Alice', false);
      await members.toggleMember('Alice');
      await members.verifyMemberSelected('Alice', true);
      
      await tester.takeScreenshot(binding, 'full_07_manage_members');

      // 6. User goes back to home and goes back to the manage members page to confirm each action is saved
      await hub.goBack();
      await hub.verifyOnHubPage();
      
      await hub.tapEventMenu('Updated Event');
      await hub.selectMenuOption('Manage Members');
      await members.verifyMemberSelected('Alice', true);
      await members.verifyMemberSelected('Bob', true);
      await members.verifyMemberSelected('Charlie', true);
      
      await hub.goBack();

      // 7. User clicks on the event to start a attendance session
      await hub.tapEventCard('Updated Event');
      await tester.pumpAndSettle();
      
      // 8. User completes the session, marking some as absent and some as present
      await tester.pumpUntilFound(find.text('Alice'));
      await attendance.markPresent(); // Alice
      await attendance.markAbsent();  // Bob
      await attendance.markPresent(); // Charlie
      
      // 9. User sees the session summary page and verifies that all changes are captured correctly
      await attendance.verifyDeckComplete();
      // Status verification (mocked in robot, but can be improved)
      await tester.takeScreenshot(binding, 'full_08_session_summary');

      // 10. User finalizes the report and goes back home to see the updated UI indicating that the session is taken
      await attendance.finishSession();
      await hub.verifyOnHubPage();
      await hub.verifyEventStatus('Updated Event', 'Taken today');
      await tester.takeScreenshot(binding, 'full_09_hub_taken');

      // 11. User clicks on the menu to go to the history page to view the just recorded session
      await hub.tapEventMenu('Updated Event');
      await hub.selectMenuOption('View History');
      
      // User validates the changes are consistent in the display of the session history
      await history.verifySessionCount(1);
      await tester.takeScreenshot(binding, 'full_10_history_page');
      
      await history.tapSession(0);
      await history.verifySummaryCounts(present: 2, absent: 1);
      await tester.takeScreenshot(binding, 'full_11_history_summary');

      // 12. User deletes the session
      await history.deleteSession();
      await history.verifySessionCount(0);
      
      // 13. User goes back home, expecting the updated UI indicating the session is awaiting being taken
      await hub.goBack();
      await hub.verifyOnHubPage();
      await hub.verifyEventStatus('Updated Event', 'Start');
      await tester.takeScreenshot(binding, 'full_12_hub_back_to_start');

      // 14. User adds another event
      await hub.tapFab();
      await event.enterName('Second Event');
      await event.save();
      await tester.pumpAndSettle();
      
      // 15. User goes to that other event manage members page
      await hub.tapEventMenu('Second Event');
      await hub.selectMenuOption('Manage Members');
      
      // User sees the other members created earlier but not checked/associated with the newly created event
      await members.verifyMember('Alice');
      await members.verifyMember('Bob');
      await members.verifyMemberSelected('Alice', false);
      await members.verifyMemberSelected('Bob', false);
      
      await tester.takeScreenshot(binding, 'full_13_other_event_members');

      // 16. User checks some of the members
      await members.toggleMember('Alice');
      await members.verifyMemberSelected('Alice', true);
      
      // 17. User goes back home and back to the manage members page to validate change persisted
      await hub.goBack();
      await hub.tapEventMenu('Second Event');
      await hub.selectMenuOption('Manage Members');
      await members.verifyMemberSelected('Alice', true);
      await members.verifyMemberSelected('Bob', false);
      
      await hub.goBack();
      await tester.takeScreenshot(binding, 'full_14_final_state');

      // Cleanup
      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });

    /* Commenting out old tests for now
    testWidgets('Full Attendance Flow', (tester) async {
       ...
    });
    ...
    */
  });
}
