import 'dart:io';
import 'package:flutter/foundation.dart';
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

  group('Data Integrity & Member Lifecycle Integration Tests', () {
    testWidgets('Verify roster warnings and database maintenance', (tester) async {
      // Ignore RenderFlex overflows for integration testing
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        final exception = details.exception;
        if (exception is FlutterError &&
            exception.message.contains('A RenderFlex overflowed')) {
          return;
        }
        originalOnError?.call(details);
      };

      final tempDir = await Directory.systemTemp.createTemp('data_integrity_test_');
      final app = await createTestApp(tempDir);

      await tester.pumpWidget(app);
      await setupScreenshots(binding);
      await tester.pump(const Duration(milliseconds: 500));

      final hub = HubRobot(tester);
      final event = EventRobot(tester);
      final members = MembersRobot(tester);
      final attendance = AttendanceRobot(tester);
      final settings = SettingsRobot(tester);

      // 1. Skip onboarding
      await tester.pumpUntilFound(find.text('Skip'));
      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(milliseconds: 500));

      // 2. Go to Manage Members and test duplicate detection
      await hub.tapSettings();
      await settings.verifyOnSettingsPage();
      await settings.tapManageMembers();
      
      await members.addMember('John Doe');
      await members.verifyMember('John Doe');
      
      // Attempt to add duplicate
      await members.addMember('John Doe');
      await members.handleDuplicateMemberDialog(true); // Add anyway
      
      // 3. Test historical accuracy info
      await members.handleHistoricalAccuracyInfo();
      
      // 4. Create an event and link members
      await hub.goBack(); // Back to Settings
      await hub.goBack(); // Back to Hub
      
      await hub.tapFab();
      await event.enterName('Test Event');
      await event.save();
      await tester.pump(const Duration(milliseconds: 800));
      
      // Link "John Doe" to event
      await hub.tapEventMenu('Test Event');
      await hub.selectMenuOption('Manage Members');
      await members.toggleMember('John Doe');
      await hub.goBack();
      
      // 5. Take attendance to create a session record
      await hub.tapEventCard('Test Event');
      await tester.pumpUntilFound(find.text('John Doe'));
      await attendance.markPresent();
      await attendance.verifyDeckComplete();
      await attendance.finishSession();
      
      // 6. Verify historical data alert when deleting member
      await hub.tapSettings();
      await settings.verifyOnSettingsPage();
      await settings.tapManageMembers();
      await members.tapDeleteMember('John Doe');
      // Should show warning because John Doe is in a session
      await members.handleConfirmDelete(true); // Final confirmation
      
      // 7. Database Maintenance (Manage Backup Data)
      await tester.clearSnackBars();
      await hub.goBack(); // Back to Settings
      await settings.tapManageBackupData();
      await settings.verifyOnManageBackupDataPage();
      
      // We should have: 1 event, 1 member (the duplicate), 1 session
      // Wait, we added "John Doe" twice. One was deleted.
      // So active records: 1 Event ("Test Event"), 1 Member ("John Doe"), 1 Session ("Test Event")
      // Total = 3
      await settings.verifyRecordCount(3);
      
      // Search feature
      await settings.searchBackup('Test');
      await settings.verifyEventListed('Test Event');
      
      // Cleanup: Delete the session from backup
      await settings.deleteBackupRecord('Test Event'); // Deletes the session
      await tester.clearSnackBars();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await settings.saveCleanedBackup();
      
      // Verify record count reduced
      await settings.tapManageBackupData();
      await settings.verifyRecordCount(2); // 1 Event, 1 Member
      
      // Final Cleanup
      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });
  });
}
