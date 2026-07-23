import 'dart:async';


import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/logging/app_logger.dart';
import 'drive_service.dart';

final _log = AppLogger('BackgroundSyncService');

const String backgroundSyncTaskName = 'com.attendance.tracker.backgroundSync';
const String backgroundSyncUniqueName = 'attendanceTrackerPeriodicSync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  try {
    Workmanager().executeTask((taskName, inputData) async {
      return await executeBackgroundTask(
        taskName,
        inputData,
      );
    });
  } catch (e, st) {
    _log.warning('Callback dispatcher error', e, st);
  }
}

Future<bool> executeBackgroundTask(
  String taskName,
  Map<String, dynamic>? inputData, {
  Future<bool> Function()? performSyncOverride,
}) async {
  _log.info('Background task executed: $taskName');
  if (taskName == backgroundSyncTaskName ||
      taskName == Workmanager.iOSBackgroundTask) {
    return await (performSyncOverride?.call() ?? performBackgroundSync());
  }
  return true;
}



Future<bool> performBackgroundSync({
  DriveService Function()? driveServiceBuilder,
}) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();

    final driveSyncEnabled = prefs.getBool('drive_sync_enabled') ?? false;
    final bgSyncEnabled =
        prefs.getBool(DriveService.backgroundSyncEnabledKey) ?? true;

    if (!driveSyncEnabled || !bgSyncEnabled) {
      _log.info('Background sync skipped: disabled in preferences');
      return true;
    }

    final driveService = driveServiceBuilder?.call() ?? DriveService();
    await driveService.init();

    if (driveService.currentUser == null) {
      _log.info('Background sync skipped: user not signed in');
      await prefs.setString(
        DriveService.lastBackgroundSyncStatusKey,
        'Skipped (Not signed in)',
      );
      return true;
    }

    await driveService.syncFiles(
      actionTitle: 'Background Auto-Sync',
      tags: ['Auto-Sync'],
    );

    final now = DateTime.now();
    await prefs.setString(
      DriveService.lastBackgroundSyncTimeKey,
      now.toIso8601String(),
    );
    await prefs.setString(
      DriveService.lastBackgroundSyncStatusKey,
      'Success',
    );
    _log.info('Background sync completed successfully at $now');
    return true;
  } catch (e, st) {
    _log.error('Background sync failed', e, st);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        DriveService.lastBackgroundSyncStatusKey,
        'Failed: $e',
      );
    } catch (_) {}
    return false;
  }
}

class BackgroundSyncService {
  BackgroundSyncService({Workmanager? workmanager})
      : _workmanager = workmanager ?? Workmanager();

  final Workmanager _workmanager;

  Future<void> initialize() async {
    try {
      await _workmanager.initialize(
        callbackDispatcher,
      );
    } catch (e, st) {
      _log.warning('Failed to initialize Workmanager', e, st);
    }
  }

  Future<void> registerPeriodicSync({bool wifiOnly = true}) async {
    try {
      final networkType =
          wifiOnly ? NetworkType.unmetered : NetworkType.connected;
      await _workmanager.registerPeriodicTask(
        backgroundSyncUniqueName,
        backgroundSyncTaskName,
        frequency: const Duration(hours: 12),
        constraints: Constraints(
          networkType: networkType,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
      _log.info(
        'Registered periodic background sync task (wifiOnly: $wifiOnly)',
      );
    } catch (e, st) {
      _log.warning('Failed to register periodic background sync', e, st);
    }
  }

  Future<void> cancelSync() async {
    try {
      await _workmanager.cancelByUniqueName(backgroundSyncUniqueName);
      _log.info('Cancelled periodic background sync task');
    } catch (e, st) {
      _log.warning('Failed to cancel background sync', e, st);
    }
  }

  Future<void> enqueueImmediateOneOffSync() async {
    try {
      await _workmanager.registerOneOffTask(
        '${backgroundSyncUniqueName}_oneoff_${DateTime.now().millisecondsSinceEpoch}',
        backgroundSyncTaskName,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
      _log.info('Enqueued immediate one-off background sync task');
    } catch (e, st) {
      _log.warning('Failed to enqueue one-off background sync', e, st);
    }
  }
}

