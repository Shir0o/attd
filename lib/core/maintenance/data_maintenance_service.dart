import 'package:shared_preferences/shared_preferences.dart';
import '../../data/session_repository.dart';
import '../../features/attendance/data/attendance_repository.dart';
import '../../features/hub/data/event_repository.dart';
import '../logging/app_logger.dart';

final _log = AppLogger('DataMaintenance');

class DataMaintenanceService {
  DataMaintenanceService({
    required this.attendanceRepository,
    required this.eventRepository,
    required this.sessionRepository,
    required this.prefs,
  });

  final AttendanceRepository attendanceRepository;
  final EventRepository eventRepository;
  final SessionRepository sessionRepository;
  final SharedPreferences prefs;

  static const _lastMaintenanceKey = 'last_data_maintenance_timestamp';
  static const _maintenanceInterval = Duration(days: 7);
  static const _pruneThreshold = Duration(days: 90);

  Future<void> runIfNeeded() async {
    final lastRunMillis = prefs.getInt(_lastMaintenanceKey) ?? 0;
    final lastRun = DateTime.fromMillisecondsSinceEpoch(lastRunMillis);
    final now = DateTime.now();

    if (now.difference(lastRun) > _maintenanceInterval) {
      await performMaintenance();
      await prefs.setInt(_lastMaintenanceKey, now.millisecondsSinceEpoch);
    }
  }

  Future<void> performMaintenance() async {
    final threshold = DateTime.now().subtract(_pruneThreshold);

    try {
      await Future.wait([
        attendanceRepository.pruneSoftDeleted(threshold),
        eventRepository.pruneSoftDeleted(threshold),
        sessionRepository.pruneSoftDeleted(threshold),
      ]);
      _log.info('Pruning completed successfully.');
    } catch (e, st) {
      _log.error('Error during pruning', e, st);
    }
  }
}
