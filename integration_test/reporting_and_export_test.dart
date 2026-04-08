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

      // 1. Skip onboarding
      await tester.pumpUntilFound(find.text('Skip'));
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // 2. Create event and members
      await hub.tapFab();
      await event.enterName('Report Event');
      await event.save();
      await tester.pump(const Duration(milliseconds: 800));

      await hub.tapEventMenu('Report Event');
      await hub.selectMenuOption('Manage Members');
      await members.addMember('Reporter Alice');
      await hub.goBack();

      // 3. Take attendance
      await hub.tapEventCard('Report Event');
      await tester.pumpUntilFound(find.text('Reporter Alice'));
      await attendance.markPresent();
      await attendance.finishSession();

      // 4. Navigate to Settings -> Advanced Reporting
      await hub.tapSettings();
      
      final advancedReportingTile = find.text('Advanced Reporting');
      await tester.pumpUntilFound(advancedReportingTile);
      await tester.ensureVisible(advancedReportingTile);
      await tester.pumpAndSettle();
      await tester.tap(advancedReportingTile);
      await tester.pumpAndSettle();

      // 5. Verify Export Page components
      await tester.pumpUntilFound(find.text('Output format'));
      expect(find.text('CSV'), findsOneWidget);
      
      // Select Excel or PDF if available
      if (tester.any(find.text('PDF'))) {
          await tester.tap(find.text('PDF'));
          await tester.pumpAndSettle();
      }

      // 6. Trigger Export
      final exportButton = find.text('Generate report');
      await tester.tap(exportButton);
      
      // Wait for processing
      await tester.pumpUntilFound(find.textContaining('Saved'));
      print('DEBUG: Report generated successfully');

      // 7. Share Result (verify button exists and is enabled)
      final shareButton = find.byIcon(Icons.share);
      expect(shareButton, findsOneWidget);
      // We can't easily verify the OS share sheet in integration tests,
      // but we verify the app state allows it.
      await tester.tap(shareButton);
      await tester.pump(const Duration(seconds: 1));
      
      // Cleanup
      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });
  });
}
