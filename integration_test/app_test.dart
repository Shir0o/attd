import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'utils/test_utils.dart';
import 'robots/hub_robot.dart';
import 'robots/event_robot.dart';
import 'robots/members_robot.dart';
import 'robots/attendance_robot.dart';
import 'robots/settings_robot.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Attendance App Integration Tests', () {
    testWidgets('Full Attendance Flow', (tester) async {
      // Required for taking screenshots on Android
      await binding.convertFlutterSurfaceToImage();

      // 1. Setup
      final tempDir = await Directory.systemTemp.createTemp('attendance_test_');
      final app = await createTestApp(tempDir);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final hub = HubRobot(tester);
      final event = EventRobot(tester);
      final members = MembersRobot(tester);
      final attendance = AttendanceRobot(tester);
      final settings = SettingsRobot(tester);

      // Screenshot 1: Hub (Initial Empty State)
      await tester.takeScreenshot(binding, '01_hub_empty');
      await tester.pumpAndSettle();

      // 2. Add Family & Members via Settings
      // Start from Hub
      await hub.verifyOnHubPage();
      await hub.tapSettings();
      // On Settings Page
      await settings.tapManageMembers();

      // Screenshot 2: Members Page
      await tester.takeScreenshot(binding, '02_members_page');
      await tester.pumpAndSettle();

      // On Members Page (Flattened)
      await members.addMember('John Doe');
      await members.addMember('Jane Smith');
      await members.addMember('Bob Wilson');

      // Go back to Hub
      await tester.tap(find.byType(BackButton).last); // Back from Members to Settings
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back).last); // Back from Settings to Hub
      await tester.pumpAndSettle();

      await hub.verifyOnHubPage();

      // 3. Create Event 1: Table Meeting
      await hub.tapFab();
      await event.enterName('Table Meeting');
      await event.selectFrequency('Weekly');
      
      // Screenshot 3: Event Creation
      await tester.takeScreenshot(binding, '03_event_creation');
      await tester.pumpAndSettle();

      // Default day is today, which is fine
      await event.save();
      await tester.pumpAndSettle();

      await hub.verifyEventCard('Table Meeting');
      await tester.pumpAndSettle();

      // Screenshot 4: Hub with Event
      await tester.takeScreenshot(binding, '04_hub_one_event');
      await tester.pumpAndSettle();

      // Create Event 2: Hall Cleaning (to show a list)
      await hub.tapFab();
      await event.enterName('Hall Cleaning');
      await event.selectFrequency('Monthly');
      await event.save();
      await tester.pumpAndSettle();

      await hub.verifyEventCard('Hall Cleaning');
      await tester.pumpAndSettle();

      // Screenshot 5: Hub with List
      await tester.takeScreenshot(binding, '05_hub_multiple_events');
      await tester.pumpAndSettle();

      // 4. Start Session for Table Meeting
      await hub.tapEventCard('Table Meeting');
      await tester.pumpAndSettle();

      // 5. Mark Attendance
      // Should see member cards
      await tester.pumpUntilFound(find.text('John Doe'));

      // Screenshot 6: Attendance Deck
      await tester.takeScreenshot(binding, '06_attendance_taking');
      await tester.pumpAndSettle();

      await attendance.markPresent(); // Mark John Doe present
      await attendance.markAbsent();  // Mark Jane Smith absent
      await attendance.markPresent(); // Mark Bob Wilson present

      // Verify Deck Complete
      await attendance.verifyDeckComplete();

      // 6. Verify Summary
      await attendance.verifyMemberStatus('John Doe', 'Present');
      await attendance.verifyMemberStatus('Jane Smith', 'Absent');
      await attendance.verifyMemberStatus('Bob Wilson', 'Present');

      // Screenshot 7: Session Summary
      await tester.takeScreenshot(binding, '07_session_summary');
      await tester.pumpAndSettle();

      // 7. Finish Session
      await attendance.finishSession(); // This goes back to Hub
      await tester.pumpAndSettle();

      // 8. Verify Hub Stats
      // Should see updated stats on the card
      await hub.verifyEventCard('Table Meeting');
      await tester.pumpUntilFound(find.text('Taken today'));
      await tester.pumpAndSettle();

      // Screenshot 8: Hub Updated (Show stats)
      await tester.takeScreenshot(binding, '08_hub_with_stats');
      await tester.pumpAndSettle();

      // Cleanup
      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });

    testWidgets('Event Management Flow', (tester) async {
      // ... (no screenshots here)
    });

    testWidgets('Member Addition and Swipe Flow', (tester) async {
      await binding.convertFlutterSurfaceToImage();

      // 1. Setup
      final tempDir = await Directory.systemTemp.createTemp('swipe_test_');
      final app = await createTestApp(tempDir);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final hub = HubRobot(tester);
      final event = EventRobot(tester);
      final members = MembersRobot(tester);
      final attendance = AttendanceRobot(tester);
      final settings = SettingsRobot(tester);

      // 2. Add multiple members to have a decent deck
      await hub.tapSettings();
      await settings.tapManageMembers();
      
      await members.addMember('Alice Adams');
      await members.addMember('Charlie Brown');
      await members.addMember('David Miller');

      await tester.takeScreenshot(binding, '09_swipe_members_added');
      await tester.pumpAndSettle();

      // Back to Hub
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back).last);
      await tester.pumpAndSettle();

      // 3. Create Event
      await hub.tapFab();
      await event.enterName('Community Gathering');
      await event.selectFrequency('One-time');
      await event.save();
      await tester.pumpAndSettle();

      await hub.verifyEventCard('Community Gathering');
      await tester.pumpAndSettle();
      
      // Screenshot 10: Hub before swipe session
      await tester.takeScreenshot(binding, '10_hub_before_swipe');
      await tester.pumpAndSettle();

      // 4. Start Session
      await hub.tapEventCard('Community Gathering');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      await tester.pumpUntilFound(find.text('Alice Adams'));
      await tester.pumpAndSettle();
      
      // Screenshot 11: Swipe Deck Start
      await tester.takeScreenshot(binding, '11_swipe_start');
      await tester.pumpAndSettle();

      // 5. Use swipe gestures
      // Swipe Alice present
      await attendance.swipeRight();
      await tester.pumpAndSettle();

      // Swipe Charlie absent
      await attendance.swipeLeft();
      await tester.pumpAndSettle();

      // Swipe David present
      await attendance.swipeRight();
      await tester.pumpAndSettle();

      // 6. Verify Summary
      await attendance.verifyDeckComplete();
      await attendance.verifyMemberStatus('Alice Adams', 'Present');
      await attendance.verifyMemberStatus('Charlie Brown', 'Absent');
      await attendance.verifyMemberStatus('David Miller', 'Present');

      // Screenshot 12: Swipe Summary
      await tester.takeScreenshot(binding, '12_swipe_summary');
      await tester.pumpAndSettle();

      // 7. Finish
      await attendance.finishSession();
      await tester.pumpAndSettle();
      await hub.verifyEventCard('Community Gathering');
      await tester.pumpAndSettle();

      // Screenshot 13: Hub Final Swipe
      await tester.takeScreenshot(binding, '13_hub_final_swipe');
      await tester.pumpAndSettle();

      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });
  });
}
