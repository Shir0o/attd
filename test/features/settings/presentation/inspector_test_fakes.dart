// Minimal in-memory repositories for storage inspector tests.
import 'package:attendance_tracker/data/local_session_repository.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/hub/data/local_event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';

class InspectorFamilies extends LocalJsonAttendanceRepository {
  InspectorFamilies(this.families);
  List<Family> families;
  @override
  Future<List<Family>> fetchAllFamilies() async => families;
  @override
  Future<List<Family>> fetchFamilies() async => families;
  @override
  Future<void> saveFamilies(List<Family> families) async => this.families = families;
  @override
  Future<void> refresh() async {}
}

class InspectorEvents extends LocalJsonEventRepository {
  InspectorEvents(this.events);
  List<Event> events;
  @override
  Future<List<Event>> fetchAllEvents() async => events;
  @override
  Future<void> saveEvents(List<Event> events) async => this.events = events;
  @override
  Future<void> refresh() async {}
}

class InspectorSessions extends LocalJsonSessionRepository {
  InspectorSessions(this.sessions);
  List<Session> sessions;
  @override
  Future<List<Session>> fetchAllSessions() async => sessions;
  @override
  Future<void> saveSessions(List<Session> sessions) async => this.sessions = sessions;
  @override
  Future<void> refresh() async {}
}
