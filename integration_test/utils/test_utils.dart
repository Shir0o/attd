import 'dart:io';

import 'package:attendance_tracker/data/local_session_repository.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/hub/data/local_event_repository.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:attendance_tracker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> createTestApp(Directory tempDir) async {
  // Use a temporary directory for local storage to isolate tests
  final storagePath = tempDir.path;

  // Initialize SharedPreferences with empty values
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final themeController = ThemeController(prefs);

  // Initialize Repositories with custom storage path
  // Note: LocalJsonAttendanceRepository expects a FILE path if provided? Let's check constructor usage.
  // Code says: if (storagePath != null) return File(storagePath!);
  // So we should provide the full path to the file.
  final attendanceRepository = LocalJsonAttendanceRepository(storagePath: '$storagePath/families.json');

  // LocalJsonSessionRepository expects storagePath to be a directory in constructor:
  // if (storagePath != null) : Directory(storagePath!)
  final sessionRepository = LocalJsonSessionRepository(storagePath: storagePath);

  // LocalJsonEventRepository expects storagePath to be a directory
  final eventRepository = LocalJsonEventRepository(storagePath: storagePath);

  return AttendanceApp(
    themeController: themeController,
    repository: attendanceRepository,
    sessionRepository: sessionRepository,
    eventRepository: eventRepository,
    // driveService: null,
    // localBackupService: null,
  );
}

extension PumpUntilFound on WidgetTester {
  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
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
}
