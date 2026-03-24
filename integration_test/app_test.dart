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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Attendance App Integration Tests', () {
    testWidgets('Full System Scenario', (tester) async {
      // 1. Initial State: User downloads app and opens for the first time (no existing data)
      final tempDir = await Directory.systemTemp.createTemp('attendance_full_scenario_');
      final app = await createTestApp(tempDir);

      print('--- Starting Test ---');
      await tester.pumpWidget(app);
      await tester.pump(const Duration(milliseconds: 500));

      final hub = HubRobot(tester);
      final event = EventRobot(tester);
      final members = MembersRobot(tester);
      final attendance = AttendanceRobot(tester);
      final history = HistoryRobot(tester);

      print('DEBUG: Step 1 - Verify empty hub');
      await tester.pumpUntilFound(find.text('No events created yet'));

      // 2. User adds a new event
      print('DEBUG: Step 2 - Add new event');
      await hub.tapFab();

      print('DEBUG: Step 2a - Enter event name');
      await event.enterName('Original Event');

      print('DEBUG: Step 2b - Select frequency');
      await event.selectFrequency('Monthly');
      print('DEBUG: Step 2c - Select day');
      await event.selectDay('Monday');

      print('DEBUG: Step 2d - Save event');
      await event.save();
      await tester.pump(const Duration(milliseconds: 800));

      // 3. User goes back to home and sees the event
      print('DEBUG: Step 3 - Verify event on hub');
      await hub.verifyOnHubPage();
      await hub.verifyEventCard('Original Event');

      // 4. User edits the event
      print('DEBUG: Step 4 - Edit event');
      await hub.tapEventMenu('Original Event');
      await hub.selectMenuOption('Edit Event');
      
      await event.enterName('Updated Event');
      await event.selectFrequency('Weekly');
      await event.selectDay('Monday');
      
      print('DEBUG: Step 4a - Update event');
      await event.update();
      await tester.pump(const Duration(milliseconds: 800));
      await hub.verifyOnHubPage();
      await hub.verifyEventCard('Updated Event');

      // 5. User manages members
      print('DEBUG: Step 5 - Manage members');
      await hub.tapEventMenu('Updated Event');
      await hub.selectMenuOption('Manage Members');
      
      await members.addMember('Alice');
      await members.addMember('Bob');
      await members.addMember('Charlie');
      
      // User searches for members
      print('DEBUG: Step 5a - Search members');
      await members.search('Ali');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.descendant(of: find.byType(ListView), matching: find.text('Alice')), findsOneWidget);
      expect(find.descendant(of: find.byType(ListView), matching: find.text('Bob')), findsNothing);
      await members.clearSearch();
      
      // User checks/unchecks member
      print('DEBUG: Step 5b - Toggle members');
      await members.verifyMemberSelected('Alice', true);
      await members.toggleMember('Alice');
      await members.verifyMemberSelected('Alice', false);
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
      await attendance.markPresent(); // Alice
      await attendance.markAbsent();  // Bob
      await attendance.markPresent(); // Charlie
      
      // 9. User sees session summary
      print('DEBUG: Step 9 - Verify session summary');
      await attendance.verifyDeckComplete();

      // 10. User finalizes report
      print('DEBUG: Step 10 - Finalize report');
      await attendance.finishSession();
      await hub.verifyOnHubPage();
      await hub.verifyEventStatus('Updated Event', 'COMPLETED');

      // 11. User views history
      print('DEBUG: Step 11 - View history');
      await hub.tapEventMenu('Updated Event');
      await hub.selectMenuOption('View History');
      
      await history.verifySessionCount(1);
      
      await history.tapSession(0);
      await history.verifySummaryCounts(present: 2, absent: 1);

      // 12. User deletes the session
      print('DEBUG: Step 12 - Delete session');
      await history.deleteSession();
      await history.verifySessionCount(0);
      
      // 13. User goes back home
      print('DEBUG: Step 13 - Back to start');
      await hub.goBack();
      await hub.verifyOnHubPage();
      await hub.verifyEventStatus('Updated Event', 'START');

      // 14. User adds another event
      print('DEBUG: Step 14 - Add second event');
      await hub.tapFab();
      await event.enterName('Second Event');
      await event.save();
      await tester.pump(const Duration(milliseconds: 800));
      
      // 15. User verifies member isolation between events
      print('DEBUG: Step 15 - Verify member isolation');
      await hub.tapEventMenu('Second Event');
      await hub.selectMenuOption('Manage Members');
      
      await members.verifyMember('Alice');
      await members.verifyMember('Bob');
      await members.verifyMemberSelected('Alice', false);
      await members.verifyMemberSelected('Bob', false);

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

      // Cleanup
      print('DEBUG: Test complete!');
      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });
  });
}
