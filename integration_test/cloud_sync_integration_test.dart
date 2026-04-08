import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

import 'utils/test_utils.dart';
import 'robots/hub_robot.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

      // 3. Find Sync Toggle or Sign In button
      final signInButton = find.widgetWithText(FilledButton, 'Sign In');
      final syncTile = find.text('Google Drive Sync');
      await tester.pumpUntilFound(syncTile);
      
      if (tester.any(signInButton)) {
          print('DEBUG: Not signed in, verifying Sign In button');
          expect(signInButton, findsOneWidget);
      } else {
          print('DEBUG: Signed in, verifying Sync Switch');
          final switchFinder = find.descendant(
              of: find.ancestor(of: syncTile, matching: find.byType(ListTile)),
              matching: find.byType(Switch),
          );
          expect(switchFinder, findsOneWidget);
          
          // 4. Verify Cloud Backup Page (only if signed in)
          final historyTile = find.text('Cloud Version History');
          await tester.pumpUntilFound(historyTile);
          await tester.ensureVisible(historyTile);
          await tester.tap(historyTile);
          await tester.pumpAndSettle();
          expect(find.text('No Cloud Backups'), findsOneWidget);
      }

      // Cleanup
      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });
  });
}
