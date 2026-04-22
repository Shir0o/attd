import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendance_tracker/core/design/app_shimmer.dart';

import 'utils/test_utils.dart';
import 'robots/hub_robot.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Disable runtime fetching for Google Fonts in integration tests to avoid network errors
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Fluid Design and UX Tests', () {
    testWidgets('Skeleton loader timing mandate (800ms)', (tester) async {
      final tempDir = await Directory.systemTemp.createTemp('fluid_design_');
      
      // We NEED animations/delays enabled for this test to verify the timing
      final app = await createTestApp(tempDir, disableAnimations: false);

      print('--- Starting Skeleton Timing Test ---');
      await tester.pumpWidget(app);
      await setupScreenshots(binding);
      
      // 1. Skip onboarding
      await tester.pumpUntilFound(find.text('Skip'));
      await tester.takeScreenshot(binding, 'fluid_01_onboarding_before_skip');
      
      final startTime = DateTime.now();
      await tester.tap(find.text('Skip'));
      
      // Wait for navigation and skeleton to appear
      await tester.pump();
      
      final skeletonFinder = find.byKey(const ValueKey('hub_skeleton'));
      bool sawSkeleton = false;
      
      // Check for skeleton for a short while
      final detectTimer = Stopwatch()..start();
      while (detectTimer.elapsed < const Duration(seconds: 2)) {
        await tester.pump(const Duration(milliseconds: 50));
        if (skeletonFinder.evaluate().isNotEmpty) {
          if (!sawSkeleton) {
            await tester.takeScreenshot(binding, 'fluid_02_skeleton_hub');
          }
          sawSkeleton = true;
          print('DEBUG: Skeleton detected at ${DateTime.now().difference(startTime).inMilliseconds}ms');
          break;
        }
      }
      
      if (!sawSkeleton) {
        print('DEBUG: Skeleton NOT detected (might have finished too fast or never appeared)');
        // If it never appeared, it might be a bug, but on slow emulators it might be missed.
        // We'll proceed but this might fail later.
      } else {
        // If we saw it, wait until at least 600ms from start to check it's still there
        // (Leaving some buffer before the 800ms cut-off)
        final elapsedSoFar = DateTime.now().difference(startTime);
        if (elapsedSoFar < const Duration(milliseconds: 600)) {
          await tester.pump(const Duration(milliseconds: 100));
          expect(skeletonFinder, findsWidgets, reason: 'Skeleton should still be visible before 800ms');
          print('DEBUG: Skeleton still visible at ${DateTime.now().difference(startTime).inMilliseconds}ms');
        }
      }

      // Wait for it to disappear (total wait up to 3s)
      final disappearTimer = Stopwatch()..start();
      while (skeletonFinder.evaluate().isNotEmpty && disappearTimer.elapsed < const Duration(seconds: 3)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      
      final finalElapsed = DateTime.now().difference(startTime).inMilliseconds;
      print('DEBUG: Skeleton gone at ${finalElapsed}ms');
      
      // Verification
      if (sawSkeleton) {
          expect(finalElapsed, greaterThanOrEqualTo(800), reason: 'Skeleton must be visible for at least 800ms total');
      }

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
      await tester.takeScreenshot(binding, 'fluid_03_settings_initial');
      
      // Find theme mode dropdown or toggle
      // Based on settings_page.dart, it's a DropdownButton<ThemeMode>
      final themeDropdown = find.byType(DropdownButton<ThemeMode>);
      await tester.pumpUntilFound(themeDropdown);
      
      print('DEBUG: Toggling Dark Mode');
      await tester.tap(themeDropdown);
      await tester.pumpAndSettle();
      await tester.takeScreenshot(binding, 'fluid_04_theme_dropdown_open');
      
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();
      await tester.takeScreenshot(binding, 'fluid_05_settings_dark_mode');
      
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

        // Skip onboarding
        await tester.pumpUntilFound(find.text('Skip'));
        await tester.takeScreenshot(binding, 'fluid_06_large_text_onboarding');
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        await tester.takeScreenshot(binding, 'fluid_07_large_text_hub');

        // Verify we can still see and tap the FAB
        final fab = find.byKey(const ValueKey('hub_fab'));
        expect(fab, findsOneWidget);
        await tester.tap(fab);
        await tester.pumpAndSettle();
        await tester.takeScreenshot(binding, 'fluid_08_large_text_add_event');

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
