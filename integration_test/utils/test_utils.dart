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

Future<Widget> createTestApp(Directory tempDir) async {
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
  final googleSignIn = GoogleSignIn();

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
    disableAnimations: true,
  );
}

/// Call once at the start of the test to enable screenshot support on Android.
Future<void> setupScreenshots(IntegrationTestWidgetsFlutterBinding binding) async {
  try {
    await binding.convertFlutterSurfaceToImage();
  } catch (_) {
    // Ignore if not supported on this platform (e.g. iOS)
  }
}

extension PumpUntilFound on WidgetTester {
  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final timer = Stopwatch()..start();
    while (timer.elapsed < timeout) {
      await pump(const Duration(milliseconds: 100));
      if (any(finder)) {
        return;
      }
    }
    throw StateError('Pump failed: Finder $finder not found in $timeout');
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
    await binding.takeScreenshot(name);
  }
}
