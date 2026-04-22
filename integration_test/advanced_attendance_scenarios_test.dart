import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'utils/test_utils.dart';
import 'robots/hub_robot.dart';
import 'robots/event_robot.dart';
import 'robots/members_robot.dart';
import 'robots/attendance_robot.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Disable runtime fetching for Google Fonts in integration tests to avoid network errors
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Advanced Attendance Scenarios', () {
    testWidgets('Guest handling and Undo functionality', (tester) async {
      // Set a consistent surface size for integration tests
      await tester.binding.setSurfaceSize(const Size(1080, 1920));

      final tempDir = await Directory.systemTemp.createTemp('advanced_test_');
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
      await tester.takeScreenshot(binding, 'adv_01_create_event');
      await event.enterName('Advanced Event');
      // Ensure current day is selected for "today" logic
      final currentDay = [
        'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
      ][DateTime.now().weekday % 7];
      await event.selectDay(currentDay);
      await event.save();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.takeScreenshot(binding, 'adv_02_hub_with_advanced_event');

      await hub.tapEventMenu('Advanced Event');
      await hub.selectMenuOption('Manage Members');
      await members.addMember('Regular Member 1');
      await members.addMember('Regular Member 2');
      await tester.takeScreenshot(binding, 'adv_03_manage_members');
      await hub.goBack();

      // 3. Start attendance
      await hub.tapEventCard('Advanced Event');
      await tester.pumpAndSettle();
      await tester.takeScreenshot(binding, 'adv_04_attendance_start');

      // 4. Test Undo functionality
      print('DEBUG: Testing Undo');
      await tester.pumpUntilFound(find.text('Regular Member 1'));
      await attendance.markPresent();
      
      // We should now see Member 2
      await tester.pumpUntilFound(find.text('Regular Member 2'));
      await tester.takeScreenshot(binding, 'adv_05_marked_member_1');
      
      // Undo
      await attendance.undo();
      await tester.pumpUntilFound(find.text('Regular Member 1'));
      await tester.takeScreenshot(binding, 'adv_06_after_undo');
      print('DEBUG: Undo successful');

      // 5. Test Guest Handling
      print('DEBUG: Testing Guest addition');
      await attendance.markPresent(); // Mark Member 1 again
      await tester.pumpUntilFound(find.text('Regular Member 2'));
      await attendance.addGuest('Guest Visitor');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.takeScreenshot(binding, 'adv_07_guest_input');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      
      await tester.pumpUntilFound(find.text('Regular Member 2'));
      await tester.takeScreenshot(binding, 'adv_08_deck_with_guest_added');
      await attendance.markAbsent();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      
      // Now we should be at completion
      await tester.pump(const Duration(milliseconds: 1000));
      await attendance.verifyDeckComplete();
      await tester.takeScreenshot(binding, 'adv_09_deck_complete');
      
      // Verify guest is in summary (if summary is shown or by finishing and checking history)
      await attendance.finishSession();
      await tester.takeScreenshot(binding, 'adv_10_session_summary_with_guest');
      
      // 6. Verify in history
      print('DEBUG: Returning to Hub');
      await hub.goBack();
      await hub.verifyOnHubPage();
      await tester.pump(const Duration(seconds: 1));
      
      await hub.tapEventMenu('Advanced Event');
      await hub.selectMenuOption('View History');
      await tester.takeScreenshot(binding, 'adv_11_event_history');
      
      // Tap the first session record in the list
      final cardFinder = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Card),
      );
      await tester.pumpUntilFound(cardFinder);
      await tester.tap(cardFinder.first);
      
      await tester.pumpUntilFound(find.text('Regular Member 1'));
      await tester.pumpUntilFound(find.text('Guest Visitor'));
      await tester.takeScreenshot(binding, 'adv_12_session_detail_with_guest');
      print('DEBUG: Guest verified in history');

      // Allow animations to settle before finishing to prevent 'DEFUNCT' overflows
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      // Cleanup
      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });
  });
}
