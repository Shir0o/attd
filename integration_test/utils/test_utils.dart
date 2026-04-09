import 'dart:io';

import 'package:attendance_tracker/data/local_session_repository.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/hub/data/local_event_repository.dart';
import 'package:attendance_tracker/features/onboarding/application/onboarding_controller.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:attendance_tracker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_tracker/features/settings/data/drive_service.dart';
import 'package:attendance_tracker/features/settings/data/local_backup_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<Widget> createTestApp(Directory tempDir, {bool disableAnimations = true}) async {
  // Use a temporary directory for local storage to isolate tests
  final storagePath = tempDir.path;

  // Initialize SharedPreferences with onboarding completed
  SharedPreferences.setMockInitialValues({'onboarding_completed': false});
  final prefs = await SharedPreferences.getInstance();
  final themeController = ThemeController(prefs);
  final onboardingController = OnboardingController(prefs);

  // Initialize Repositories with custom storage path
  final attendanceRepository = LocalJsonAttendanceRepository(storagePath: '$storagePath/families.json');
  final sessionRepository = LocalJsonSessionRepository(storagePath: storagePath);
  final eventRepository = LocalJsonEventRepository(storagePath: storagePath);

  // Mock GoogleSignIn for DriveService
  final googleSignIn = GoogleSignIn.instance;

  final driveService = DriveService(
    googleSignIn: googleSignIn,
    attendanceRepository: attendanceRepository,
    sessionRepository: sessionRepository,
    eventRepository: eventRepository,
  );

  final localBackupService = LocalBackupService();

  return AttendanceApp(
    themeController: themeController,
    onboardingController: onboardingController,
    repository: attendanceRepository,
    sessionRepository: sessionRepository,
    eventRepository: eventRepository,
    driveService: driveService,
    localBackupService: localBackupService,
    prefs: prefs,
    disableAnimations: disableAnimations,
  );
}

Future<void> setupScreenshots(IntegrationTestWidgetsFlutterBinding binding) async {
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      // Any specific setup for mobile screenshots
    }
  } catch (e) {
    debugPrint('Screenshot setup skipped: $e');
  }
}

extension PumpUntilFound on WidgetTester {
  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    bool found = false;
    final timer = Stopwatch()..start();
    while (!found && timer.elapsed < timeout) {
      await pump(const Duration(milliseconds: 100));
      found = finder.evaluate().isNotEmpty;
    }
    if (!found) {
      throw Exception('Timed out waiting for $finder');
    }
  }

  Future<void> pumpUntilAbsent(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    bool absent = false;
    final timer = Stopwatch()..start();
    while (!absent && timer.elapsed < timeout) {
      await pump(const Duration(milliseconds: 100));
      absent = finder.evaluate().isEmpty;
    }
    if (!absent) {
      throw Exception('Timed out waiting for $finder to disappear');
    }
  }

  /// Takes a screenshot while ensuring any snackbars and the keyboard are dismissed first.
  Future<void> takeScreenshot(
    IntegrationTestWidgetsFlutterBinding binding,
    String name,
  ) async {
    // Dismiss keyboard if it's open
    FocusManager.instance.primaryFocus?.unfocus();
    await pump(const Duration(milliseconds: 500));

    // Check if there's a visible snackbar and remove it
    if (find.byType(SnackBar).evaluate().isNotEmpty) {
      final messenger = ScaffoldMessenger.maybeOf(
        element(find.byType(MaterialApp).first),
      );
      if (messenger != null) {
        messenger.clearSnackBars();
        // Need to pump to update the tree
        await pump(const Duration(milliseconds: 500));
      }
    }
    
    try {
      await binding.takeScreenshot(name);
    } catch (e) {
      debugPrint('Screenshot "$name" failed (expected in headless mode): $e');
    }
  }
}
