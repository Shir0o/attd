import 'dart:async';

import 'package:attendance_tracker/core/maintenance/data_maintenance_service.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('runIfNeeded skips maintenance when recently run', () async {
    final prefs = await _prefsWithLastRun(DateTime.now());
    final attendance = _MaintenanceAttendanceRepository();
    final events = _MaintenanceEventRepository();
    final sessions = _MaintenanceSessionRepository();

    await DataMaintenanceService(
      attendanceRepository: attendance,
      eventRepository: events,
      sessionRepository: sessions,
      prefs: prefs,
    ).runIfNeeded();

    expect(attendance.pruneCount, 0);
    expect(events.pruneCount, 0);
    expect(sessions.pruneCount, 0);
  });

  test('runIfNeeded prunes repositories and stores run timestamp', () async {
    final prefs = await _prefsWithLastRun(
      DateTime.now().subtract(const Duration(days: 8)),
    );
    final attendance = _MaintenanceAttendanceRepository();
    final events = _MaintenanceEventRepository();
    final sessions = _MaintenanceSessionRepository();

    await DataMaintenanceService(
      attendanceRepository: attendance,
      eventRepository: events,
      sessionRepository: sessions,
      prefs: prefs,
    ).runIfNeeded();

    expect(attendance.pruneCount, 1);
    expect(events.pruneCount, 1);
    expect(sessions.pruneCount, 1);
    expect(prefs.getInt('last_data_maintenance_timestamp'), isNotNull);
  });

  test('performMaintenance swallows prune failures', () async {
    final prefs = await _prefsWithLastRun(DateTime.now());

    await DataMaintenanceService(
      attendanceRepository: _MaintenanceAttendanceRepository(shouldThrow: true),
      eventRepository: _MaintenanceEventRepository(),
      sessionRepository: _MaintenanceSessionRepository(),
      prefs: prefs,
    ).performMaintenance();
  });
}

Future<SharedPreferences> _prefsWithLastRun(DateTime lastRun) async {
  SharedPreferences.setMockInitialValues({
    'last_data_maintenance_timestamp': lastRun.millisecondsSinceEpoch,
  });
  return SharedPreferences.getInstance();
}

class _MaintenanceAttendanceRepository extends AttendanceRepository {
  _MaintenanceAttendanceRepository({this.shouldThrow = false});

  final bool shouldThrow;
  int pruneCount = 0;

  @override
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) => throw UnimplementedError();

  @override
  Future<Family> addMember(String familyId, Member member) =>
      throw UnimplementedError();

  @override
  Future<List<Family>> fetchFamilies() => throw UnimplementedError();

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {
    pruneCount++;
    if (shouldThrow) throw StateError('failed');
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> saveFamilies(List<Family> families) =>
      throw UnimplementedError();

  @override
  Stream<List<Family>> streamFamilies() => const Stream.empty();
}

class _MaintenanceEventRepository implements EventRepository {
  int pruneCount = 0;

  @override
  Future<void> createEvent(Event event) => throw UnimplementedError();

  @override
  Future<void> deleteEvent(String eventId) => throw UnimplementedError();

  @override
  Future<Event?> findEventById(String eventId) => throw UnimplementedError();

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {
    pruneCount++;
  }

  @override
  Future<void> refresh() async {}

  @override
  Stream<List<Event>> streamEvents() => const Stream.empty();

  @override
  Future<void> updateEvent(Event event) => throw UnimplementedError();
}

class _MaintenanceSessionRepository implements SessionRepository {
  int pruneCount = 0;

  @override
  Future<Session> createSession({
    required String title,
    String? eventId,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteSession(String sessionId, {required String actor}) =>
      throw UnimplementedError();

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) =>
      throw UnimplementedError();

  @override
  Future<Session?> findSessionById(String id) => throw UnimplementedError();

  @override
  Future<List<SessionVersion>> history(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<List<Session>> loadSessions() => throw UnimplementedError();

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) =>
      throw UnimplementedError();

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {
    pruneCount++;
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) =>
      throw UnimplementedError();

  @override
  Stream<List<Session>> streamSessions() => const Stream.empty();
}
