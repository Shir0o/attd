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
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Reporting and Export Integration Tests', () {
    testWidgets('Complete session and export report', (tester) async {
      final tempDir = await Directory.systemTemp.createTemp('report_export_');
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

      // 2. Create Event and Members
      await hub.tapFab();
      await event.enterName('Report Event');
      await event.save();
      await tester.pump(const Duration(milliseconds: 800));

      await hub.tapEventMenu('Report Event');
      await hub.selectMenuOption('Manage Members');
      await members.addMember('Reporter Alice');
      await hub.goBack();

      // 3. Start and complete session
      await hub.tapEventCard('Report Event');
      await tester.pumpAndSettle();
      await attendance.markPresent();
      await attendance.finishSession();
      
      // 4. Go to Settings to view Export options
      print('DEBUG: Returning to Hub');
      await hub.goBack();
      await hub.verifyOnHubPage();
      await tester.pump(const Duration(seconds: 1));

      await hub.tapSettings();
      await settings.verifyOnSettingsPage();
      await tester.takeScreenshot(binding, 'export_01_settings_reporting_section');
      
      final exportButton = find.text('Export to Google Sheets');
      if (tester.any(exportButton)) {
        await tester.takeScreenshot(binding, 'export_02_export_button');
      }
      
      // Cleanup
      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });
  });
}
