import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:attendance_tracker/core/design/app_shimmer.dart';

import 'utils/test_utils.dart';
import 'robots/hub_robot.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Fluid Design and UX Tests', () {
    testWidgets('Skeleton loader timing mandate (800ms)', (tester) async {
      final tempDir = await Directory.systemTemp.createTemp('fluid_design_');
      
      // We NEED animations/delays enabled for this test to verify the timing
      final app = await createTestApp(tempDir, disableAnimations: false);

      print('--- Starting Skeleton Timing Test ---');
      await tester.pumpWidget(app);
      
      // 1. Skip onboarding
      await tester.pumpUntilFound(find.text('Skip'));
      await tester.tap(find.text('Skip'));
      // Note: HubPage itself has an 800ms delay in _loadInitialData
      
      final startTime = DateTime.now();
      
      // We expect to see AppShimmer immediately
      await tester.pump();
      expect(find.byType(AppShimmer), findsWidgets);
      print('DEBUG: Skeleton visible at ${DateTime.now().difference(startTime).inMilliseconds}ms');

      // Wait 400ms - should still be visible
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AppShimmer), findsWidgets);
      print('DEBUG: Skeleton still visible at 400ms');

      // Wait another 500ms (total 900ms) - should be gone
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(); // Final build after future completes
      
      // On an empty hub, AppShimmer might be gone but replaced by "No events"
      // Let's check if AppShimmer is gone
      expect(find.byType(AppShimmer), findsNothing);
      print('DEBUG: Skeleton gone at ${DateTime.now().difference(startTime).inMilliseconds}ms');
      
      final totalElapsed = DateTime.now().difference(startTime).inMilliseconds;
      expect(totalElapsed, greaterThanOrEqualTo(800), reason: 'Skeleton must be visible for at least 800ms');

      // Cleanup
      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });

    testWidgets('Theme switching verification', (tester) async {
      final tempDir = await Directory.systemTemp.createTemp('theme_test_');
      final app = await createTestApp(tempDir);

      await tester.pumpWidget(app);
      await setupScreenshots(binding);
      
      final hub = HubRobot(tester);

      // Skip onboarding
      await tester.pumpUntilFound(find.text('Skip'));
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Go to settings
      await hub.tapSettings();
      
      // Find theme mode dropdown or toggle
      // Based on settings_page.dart, it's a DropdownButton<ThemeMode>
      final themeDropdown = find.byType(DropdownButton<ThemeMode>);
      await tester.pumpUntilFound(themeDropdown);
      
      print('DEBUG: Toggling Dark Mode');
      await tester.tap(themeDropdown);
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();
      
      // Verify theme changed (check background color of Scaffold)
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      // Dark theme surface is usually near black/dark grey
      expect(scaffold.backgroundColor!.computeLuminance(), lessThan(0.5));
      print('DEBUG: Dark mode verified');

      // Cleanup
      if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
      }
    });
   group('Accessibility Verification', () {
      testWidgets('Large text handling', (tester) async {
        final tempDir = await Directory.systemTemp.createTemp('access_test_');
        final app = await createTestApp(tempDir);

        // Apply large text scale factor
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: app,
          ),
        );

        final hub = HubRobot(tester);

        // Skip onboarding
        await tester.pumpUntilFound(find.text('Skip'));
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        // Verify we can still see and tap the FAB
        final fab = find.byKey(const ValueKey('hub_fab'));
        expect(fab, findsOneWidget);
        await tester.tap(fab);
        await tester.pumpAndSettle();

        // Verify "New Event" title is still visible and not overflowed
        expect(find.text('New Event'), findsOneWidget);
        
        // Cleanup
        if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
        }
      });
    });
  });
}
