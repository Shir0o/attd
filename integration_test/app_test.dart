import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'utils/test_utils.dart';
import 'robots/hub_robot.dart';
import 'robots/event_robot.dart';
import 'robots/members_robot.dart';
import 'robots/attendance_robot.dart';
import 'robots/settings_robot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Attendance App Integration Tests', () {
    testWidgets('Full Attendance Flow', (tester) async {
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

      // 2. Add Family & Members via Settings
      // Start from Hub
      await hub.verifyOnHubPage();
      await hub.tapSettings();
      // On Settings Page
      await settings.tapManageMembers();

      // On Members Page (Flattened)
      await members.addMember('John Doe');
      await members.verifyMember('John Doe');

      // Go back to Hub
      await tester.pageBack(); // Back to Settings
      await tester.pumpAndSettle();
      await tester.pageBack(); // Back to Hub
      await tester.pumpAndSettle();

      await hub.verifyOnHubPage();

      // 3. Create Event
      await hub.tapFab();
      await event.enterName('Weekly Meeting');
      await event.selectFrequency('Weekly');
      // Default day is today, which is fine
      await event.save();

      await hub.verifyEventCard('Weekly Meeting');

      // 4. Start Session
      await hub.tapEventCard('Weekly Meeting');

      // 5. Mark Attendance
      // Should see John Doe card
      // Wait for session to be created/loaded
      await tester.pumpUntilFound(find.text('John Doe'));
      await attendance.markPresent(); // Mark John Doe present

      // Since only 1 member, should go to Summary
      await attendance.verifyDeckComplete();

      // 6. Verify Summary
      await attendance.verifyMemberStatus('John Doe', 'Present');

      // 7. Finish Session
      await attendance.finishSession(); // This goes back to Hub

      // 8. Verify Hub Stats
      // Should see updated stats on the card
      await hub.verifyEventCard('Weekly Meeting');
      await tester.pumpUntilFound(find.text('Taken today'));

      // Cleanup
      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });

    testWidgets('Event Management Flow', (tester) async {
      final tempDir = await Directory.systemTemp.createTemp('attendance_test_mgmt_');
      final app = await createTestApp(tempDir);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final hub = HubRobot(tester);
      final event = EventRobot(tester);

      // Create Event
      await hub.tapFab();
      await event.enterName('Temp Event');
      await event.save();
      await hub.verifyEventCard('Temp Event');

      // Edit Event
      await hub.tapEventMenu('Temp Event');
      await hub.selectMenuOption('Edit Event');
      await event.enterName('Renamed Event');
      await event.update(); // Uses "Save Changes" button

      await hub.verifyEventCard('Renamed Event');
      expect(find.text('Temp Event'), findsNothing);

      // Delete Event
      await hub.tapEventMenu('Renamed Event');
      await hub.selectMenuOption('Delete Event'); // Opens confirmation dialog

      // The menu option 'Delete Event' shows a dialog.
      // We need to tap 'Delete' on the dialog.
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Renamed Event'), findsNothing);

      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });
  });
}
