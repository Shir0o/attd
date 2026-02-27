import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'utils/test_utils.dart';
import 'robots/hub_robot.dart';
import 'robots/event_robot.dart';
import 'robots/members_robot.dart';
import 'robots/attendance_robot.dart';
import 'robots/settings_robot.dart';
import 'robots/summary_robot.dart';
import 'robots/history_robot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Comprehensive Scenario Tests', () {
    testWidgets('Scenario 1: Advanced Session Control (Guest & Undo)', (tester) async {
      // 1. Setup
      final tempDir = await Directory.systemTemp.createTemp('scenario1_');
      final app = await createTestApp(tempDir);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final hub = HubRobot(tester);
      final event = EventRobot(tester);
      final members = MembersRobot(tester);
      final attendance = AttendanceRobot(tester);
      final settings = SettingsRobot(tester);
      final summary = SummaryRobot(tester);

      // 2. Add a member
      await hub.tapSettings();
      await settings.tapManageMembers();
      await members.addMember('Alice');
      await tester.pageBack();
      await tester.pageBack();

      // 3. Create Event
      await hub.tapFab();
      await event.enterName('Chess Club');
      await event.save();

      // 4. Start Session
      await hub.tapEventCard('Chess Club');
      await attendance.verifyCardVisible('Alice');

      // 5. Test Undo
      await attendance.markPresent(); // Alice Present
      // Oops, meant absent
      // Ideally we should see the undo button enabled
      await attendance.undoSwipe();
      await attendance.verifyCardVisible('Alice'); // Should see Alice again

      // 6. Mark Absent correctly this time
      await attendance.markAbsent();

      // 7. Add Guest
      await attendance.addGuest('Guest Bob', isPresent: true);
      // After adding guest, it usually auto-records and stays on deck or summary if done.
      // Since Alice was last member, and we swiped her, adding guest might trigger completion if logic allows.
      // But we undid Alice. Then swiped Absent. So Alice is done.
      // The deck should be empty/complete.

      await attendance.verifyDeckComplete();

      // 8. Verify Summary
      await summary.verifyMemberStatus('Alice', isPresent: false);
      await summary.verifyMemberStatus('Guest Bob', isPresent: true);

      // 9. Edit from Summary (Toggle Alice to Present)
      await summary.toggleMember('Alice');
      await summary.verifyMemberStatus('Alice', isPresent: true);

      // 10. Finalize
      await summary.finalizeReport();
      await hub.verifyOnHubPage();

      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });

    testWidgets('Scenario 2: Event-Scoped Membership', (tester) async {
      final tempDir = await Directory.systemTemp.createTemp('scenario2_');
      final app = await createTestApp(tempDir);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final hub = HubRobot(tester);
      final event = EventRobot(tester);
      final members = MembersRobot(tester);
      final attendance = AttendanceRobot(tester);
      final settings = SettingsRobot(tester);

      // 1. Add Members Global
      await hub.tapSettings();
      await settings.tapManageMembers();
      await members.addMember('Alice');
      await members.addMember('Bob');
      await members.addMember('Charlie');
      await tester.pageBack();
      await tester.pageBack();

      // 2. Create Event
      await hub.tapFab();
      await event.enterName('Team Alpha');
      await event.save();

      // 3. Configure Event Members
      await hub.tapEventMenu('Team Alpha');
      await hub.selectMenuOption('Manage Members');

      // Select Alice and Charlie, Deselect Bob (if selected by default? Usually empty by default or full?)
      // Current implementation logic: empty list means ALL members.
      // But if we select someone, it becomes inclusive list.
      // Let's explicitly select Alice.
      // Wait, we need to check the UI behavior.
      // If memberIds is empty -> All members shown?
      // Let's verify default behavior first.

      // Actually, let's just Select Alice.
      // Finding checkboxes might be tricky if they are not labelled.
      // The robot uses text to find row then checkbox.

      // Tap Alice to select
      await members.toggleMemberInEvent('Alice'); // Select
      // Tap Charlie to select
      await members.toggleMemberInEvent('Charlie'); // Select

      // Bob remains unselected (assuming started unselected)

      await tester.pageBack(); // Back to Hub

      // 4. Start Session
      await hub.tapEventCard('Team Alpha');

      // 5. Verify Deck contains only Alice and Charlie
      // We expect to see Alice or Charlie first.
      // Order is alphabetical usually.
      await attendance.verifyCardVisible('Alice');
      await attendance.markPresent();

      await attendance.verifyCardVisible('Charlie');
      await attendance.markPresent();

      // Should be done now, Bob should be skipped
      await attendance.verifyDeckComplete();

      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });

    testWidgets('Scenario 3: Historical Data Integrity', (tester) async {
      final tempDir = await Directory.systemTemp.createTemp('scenario3_');
      final app = await createTestApp(tempDir);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final hub = HubRobot(tester);
      final event = EventRobot(tester);
      final members = MembersRobot(tester);
      final attendance = AttendanceRobot(tester);
      final settings = SettingsRobot(tester);
      final history = HistoryRobot(tester);
      final summary = SummaryRobot(tester);

      // 1. Setup
      await hub.tapSettings();
      await settings.tapManageMembers();
      await members.addMember('Alice');
      await tester.pageBack();
      await tester.pageBack();

      await hub.tapFab();
      await event.enterName('History Class');
      await event.save();

      // 2. create Session 1
      await hub.tapEventCard('History Class');
      await attendance.markPresent(); // Alice Present
      await attendance.finishSession();

      // 3. Create Session 2 (Simulate next day? Or just another session)
      // Since app defaults to "Today", clicking again opens summary of Today.
      // We need to create a NEW session or modify date?
      // The Hub logic: "Taken today" -> Opens Summary.
      // So we can't easily create another session for TODAY via UI without deleting/editing.

      // However, we can use History to view the one we just made.

      // 4. Open History
      await hub.openEventHistory('History Class');
      await history.verifyOnHistoryPage('History Class');

      // Verify session listed
      // It should show date.
      // Let's just tap the first card.
      await tester.tap(find.byType(Card).first);
      await tester.pumpAndSettle();

      // 5. Verify Summary Content
      await summary.verifyMemberStatus('Alice', isPresent: true);

      // 6. Modify Past Session
      await summary.toggleMember('Alice'); // Mark Absent
      await summary.verifyMemberStatus('Alice', isPresent: false);

      // 7. Go back and Verify update in History list (optional, might need refresh)
      await tester.pageBack(); // Back to History
      await tester.pumpAndSettle();

      // Check if badge updated?
      // The history list shows Present/Absent counts.
      // Should be 0 Present, 1 Absent now.
      await tester.pumpUntilFound(find.text('0 Present'));
      await tester.pumpUntilFound(find.text('1 Absent'));

      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });
  });
}
