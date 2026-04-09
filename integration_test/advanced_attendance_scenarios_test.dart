import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

import 'utils/test_utils.dart';
import 'robots/hub_robot.dart';
import 'robots/event_robot.dart';
import 'robots/members_robot.dart';
import 'robots/attendance_robot.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Advanced Attendance Scenarios', () {
    testWidgets('Guest handling and Undo functionality', (tester) async {
      final tempDir = await Directory.systemTemp.createTemp('advanced_attendance_');
      final app = await createTestApp(tempDir);

      await tester.pumpWidget(app);
      await setupScreenshots(binding);
      await tester.pump(const Duration(milliseconds: 500));

      final hub = HubRobot(tester);
      final event = EventRobot(tester);
      final members = MembersRobot(tester);
      final attendance = AttendanceRobot(tester);

      // 1. Skip onboarding
      await tester.pumpUntilFound(find.text('Skip'));
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // 2. Create event with one member
      await hub.tapFab();
      await event.enterName('Advanced Event');
      // Ensure current day is selected for "today" logic
      final currentDay = [
        'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
      ][DateTime.now().weekday % 7];
      await event.selectDay(currentDay);
      await event.save();
      await tester.pump(const Duration(milliseconds: 800));

      await hub.tapEventMenu('Advanced Event');
      await hub.selectMenuOption('Manage Members');
      await members.addMember('Regular Member 1');
      await members.addMember('Regular Member 2');
      await hub.goBack();

      // 3. Start attendance
      await hub.tapEventCard('Advanced Event');
      await tester.pumpAndSettle();

      // 4. Test Undo functionality
      print('DEBUG: Testing Undo');
      await tester.pumpUntilFound(find.text('Regular Member 1'));
      await attendance.markPresent();
      
      // We should now see Member 2
      await tester.pumpUntilFound(find.text('Regular Member 2'));
      
      // Undo
      await attendance.undo();
      await tester.pumpUntilFound(find.text('Regular Member 1'));
      print('DEBUG: Undo successful');

      // 5. Test Guest Handling
      print('DEBUG: Testing Guest addition');
      await attendance.markPresent(); // Mark Member 1 again
      await tester.pumpUntilFound(find.text('Regular Member 2'));
      await attendance.addGuest('Guest Visitor');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      
      await tester.pumpUntilFound(find.text('Regular Member 2'));
      await attendance.markAbsent();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      
      // Now we should be at completion
      await tester.pump(const Duration(milliseconds: 1000));
      await attendance.verifyDeckComplete();
      
      // Verify guest is in summary (if summary is shown or by finishing and checking history)
      await attendance.finishSession();
      
      // 6. Verify in history
      print('DEBUG: Returning to Hub');
      await hub.goBack();
      await hub.verifyOnHubPage();
      await tester.pump(const Duration(seconds: 1));
      
      await hub.tapEventMenu('Advanced Event');
      await hub.selectMenuOption('View History');
      
      // Tap the first session record in the list
      final cardFinder = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Card),
      );
      await tester.pumpUntilFound(cardFinder);
      await tester.tap(cardFinder.first);
      
      await tester.pumpUntilFound(find.text('Regular Member 1'));
      await tester.pumpUntilFound(find.text('Guest Visitor'));
      print('DEBUG: Guest verified in history');

      // Cleanup
      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });
  });
}
