import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:attendance_tracker/core/design/widgets/conv_widgets.dart';

import 'utils/test_utils.dart';
import 'robots/hub_robot.dart';
import 'robots/members_robot.dart';
import 'robots/settings_robot.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Disable runtime fetching for Google Fonts in integration tests to avoid network errors
  // GoogleFonts.config.allowRuntimeFetching = false;

  group('Resilience and Failure State Tests', () {
    testWidgets('Empty state verification across major pages', (tester) async {
      final tempDir = await Directory.systemTemp.createTemp('resilience_empty_');
      final app = await createTestApp(tempDir);

      await tester.pumpWidget(app);
      await setupScreenshots(binding);
      await tester.pump(const Duration(milliseconds: 500));

      final hub = HubRobot(tester);
      final members = MembersRobot(tester);
      final settings = SettingsRobot(tester);

      // 1. Skip onboarding
      await tester.pumpUntilFound(find.text('Skip'));
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // 2. Hub Empty State
      print('DEBUG: Verifying Hub empty state');
      await tester.pumpUntilFound(find.text('Nothing on the calendar yet.'));

      // 3. Members Empty State
      print('DEBUG: Verifying Members empty state');
      await hub.tapSettings();
      await settings.tapManageMembers();
      // Verify the new Convocation header reports an empty roster.
      await tester.pumpUntilFound(find.text('0 people'));
      expect(find.text('0 families'), findsOneWidget);

      // 4. Search Empty State
      print('DEBUG: Verifying Search empty state');
      await members.search('NonExistentPerson');
      // With no matches, no member rows (and therefore no avatars) render.
      expect(find.byType(ConvAvatar), findsNothing);
      await members.clearSearch();

      // 5. Manage Backup Data Empty State
      print('DEBUG: Verifying Backup empty state');
      await hub.goBack(); // Back to Settings
      await settings.tapManageBackupData();
      await settings.verifyOnManageBackupDataPage();
      // Record count should be 0
      await settings.verifyRecordCount(0);

      // Cleanup
      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });

    testWidgets('Validation error feedback', (tester) async {
      final tempDir = await Directory.systemTemp.createTemp('resilience_validation_');
      final app = await createTestApp(tempDir);

      await tester.pumpWidget(app);
      await tester.pumpUntilFound(find.text('Skip'));
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      final hub = HubRobot(tester);

      // Try to create event with empty name
      await hub.tapFab();
      // "New Event" page
      final saveButton = find.byKey(const ValueKey('save_event_button'));
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      
      // Should show validation error
      expect(find.text('Please enter an event name'), findsOneWidget);
      print('DEBUG: Validation error verified');

      // Cleanup
      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });
  });
}
