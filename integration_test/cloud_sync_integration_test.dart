import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

import 'utils/test_utils.dart';
import 'robots/hub_robot.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Disable runtime fetching for Google Fonts in integration tests to avoid network errors
  // GoogleFonts.config.allowRuntimeFetching = false;

  group('Cloud Sync Integration (Conceptual)', () {
    testWidgets('Google Drive Sync toggle and Status', (tester) async {
      final tempDir = await Directory.systemTemp.createTemp('sync_test_');
      final app = await createTestApp(tempDir);

      await tester.pumpWidget(app);
      await setupScreenshots(binding);
      
      final hub = HubRobot(tester);

      // 1. Skip onboarding
      await tester.pumpUntilFound(find.text('Skip'));
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // 2. Navigate to Settings
      await hub.tapSettings();
      await tester.takeScreenshot(binding, 'cloud_01_settings_sync');

      // 3. Find Sync Toggle or Sign In button
      final signInButton = find.widgetWithText(FilledButton, 'Sign In');
      final syncTile = find.text('Google Drive');
      await tester.pumpUntilFound(syncTile);
      
      if (tester.any(signInButton)) {
          print('DEBUG: Not signed in, verifying Sign In button');
          expect(signInButton, findsOneWidget);
          await tester.takeScreenshot(binding, 'cloud_02_not_signed_in');
      } else {
          print('DEBUG: Signed in, verifying Sync Switch');
          final switchFinder = find.descendant(
              of: find.ancestor(of: syncTile, matching: find.byType(ListTile)),
              matching: find.byType(Switch),
          );
          expect(switchFinder, findsOneWidget);
          await tester.takeScreenshot(binding, 'cloud_02_signed_in_sync_enabled');
          
          // 4. Verify Cloud Backup Page (only if signed in)
          final historyTile = find.text('Cloud Version History');
          await tester.pumpUntilFound(historyTile);
          await tester.ensureVisible(historyTile);
          await tester.takeScreenshot(binding, 'cloud_03_cloud_history_tile');
          await tester.tap(historyTile);
          await tester.pumpAndSettle();
          await tester.takeScreenshot(binding, 'cloud_04_cloud_history_empty');
          expect(find.text('No Cloud Backups'), findsOneWidget);
      }

      // Cleanup
      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });
  });
}
