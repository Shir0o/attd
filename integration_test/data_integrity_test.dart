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
  // Disable runtime fetching for Google Fonts in integration tests to avoid network errors
  // GoogleFonts.config.allowRuntimeFetching = false;

  group('Data Integrity & Member Lifecycle Integration Tests', () {
    testWidgets('Verify roster warnings and database maintenance', (tester) async {
      // Ignore RenderFlex overflows for integration testing
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exception is FlutterError && (details.exception as FlutterError).message.contains('A RenderFlex overflowed')) {
          return;
        }
        originalOnError?.call(details);
      };

      final tempDir = await Directory.systemTemp.createTemp('data_integrity_');
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
      await tester.pumpAndSettle();

      // 2. Setup initial state: Event + Members
      await hub.tapFab();
      await event.enterName('Test Event');
      await event.save();
      await tester.pump(const Duration(milliseconds: 800));

      await hub.tapEventMenu('Test Event');
      await hub.selectMenuOption('Manage Members');
      await members.addMember('John Doe');
      await members.addMember('Jane Smith');
      
      // 3. Test Duplicate Member Warning
      print('DEBUG: Testing Duplicate Member Warning');
      await members.addMember('John Doe');
      await tester.takeScreenshot(binding, 'data_01_duplicate_member_dialog');
      await members.handleDuplicateMemberDialog(true); // Add anyway
      await members.verifyMember('John Doe'); // Should have two now
      
      await hub.goBack();
      await tester.takeScreenshot(binding, 'data_02_hub_with_duplicates');

      // 4. Start attendance and mark John Doe
      await hub.tapEventCard('Test Event');
      await tester.pumpAndSettle();
      await tester.pumpUntilFound(find.text('John Doe'));
      await tester.takeScreenshot(binding, 'data_03_attendance_card');
      await attendance.markPresent();
      await tester.pumpAndSettle();
      
      // Cancel session partway - Use tooltip to avoid ambiguity with absent button
      print('DEBUG: Cancelling session partway');
      final cancelFinder = find.byTooltip('Cancel');
      await tester.pumpUntilFound(cancelFinder);
      await tester.takeScreenshot(binding, 'data_04_attendance_cancel_confirmation');
      await tester.tap(cancelFinder);
      await tester.pumpAndSettle();

      // 5. Test Historical Accuracy Info
      print('DEBUG: Testing Historical Accuracy Info');
      await hub.tapSettings();
      await tester.takeScreenshot(binding, 'data_05_settings');
      await settings.tapManageMembers();
      await tester.takeScreenshot(binding, 'data_06_manage_members_accuracy_info');
      await members.handleHistoricalAccuracyInfo();

      // 6. Test Member Removal with linked data
      print('DEBUG: Testing Member deletion with dependencies');
      await members.tapDeleteMember('John Doe');
      await tester.takeScreenshot(binding, 'data_07_confirm_delete_warning');
      // Should show warning because John Doe is in a session
      await members.handleConfirmDelete(true); // Final confirmation
      
      // 7. Database Maintenance (Manage Backup Data)
      ScaffoldMessenger.maybeOf(tester.element(find.byType(MaterialApp).first))?.clearSnackBars();
      await tester.pump(const Duration(milliseconds: 500));

      await hub.goBack(); // Back to Settings
      await settings.tapManageBackupData();
      await settings.verifyOnManageBackupDataPage();
      await tester.takeScreenshot(binding, 'data_08_manage_backup_data');
      
      // 1 Event + 2 Members (one was deleted) + 1 Session = 4.
      await settings.verifyRecordCount(4); 

      await settings.searchBackup('Test');
      await settings.verifyEventListed('Test Event');
      await tester.takeScreenshot(binding, 'data_09_backup_search');
      
      // Cleanup: Delete the session from backup
      print('DEBUG: Deleting record from backup');
      await settings.deleteBackupRecord('Test Event'); // Deletes the session
      await tester.takeScreenshot(binding, 'data_10_after_delete_backup_record');
      ScaffoldMessenger.maybeOf(tester.element(find.byType(MaterialApp).first))?.clearSnackBars();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.pumpAndSettle(const Duration(seconds: 1));
      
      // Verify record count reduced: 4 -> 3 (pending deletion)
      await settings.verifyRecordCount(3); 

      await settings.saveCleanedBackup();
      
      // Restore error handler
      FlutterError.onError = originalOnError;
      
      // Cleanup
      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });
  });
}
