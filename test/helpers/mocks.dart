import 'dart:async';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/auth/domain/entities/credentials.dart';
import 'package:attendance_tracker/features/auth/domain/entities/google_account.dart';
import 'package:attendance_tracker/features/auth/domain/entities/user.dart';
import 'package:attendance_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';

class MockAttendanceRepository extends AttendanceRepository {
  List<Family> _families = [];
  final _controller = StreamController<List<Family>>.broadcast();

  void setFamilies(List<Family> families) {
    _families = families;
    _controller.add(families);
  }

  @override
  Future<List<Family>> fetchFamilies() async => _families;

  @override
  Future<void> saveFamilies(List<Family> families) async {
    _families = families;
    _controller.add(families);
  }

  @override
  Future<Family> addMember(String familyId, Member member) async {
    throw UnimplementedError();
  }

  @override
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) async {
    throw UnimplementedError();
  }

  @override
  Stream<List<Family>> streamFamilies() {
    return _controller.stream;
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class MockEventRepository implements EventRepository {
  final _controller = StreamController<List<Event>>.broadcast();
  List<Event> _events = [];

  void emit(List<Event> events) {
    _events = events;
    _controller.add(events);
  }

  @override
  Future<void> createEvent(Event event) async {
    _events.add(event);
    _controller.add(_events);
  }

  @override
  Future<void> updateEvent(Event event) async {
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      _events[index] = event;
      _controller.add(_events);
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    _events.removeWhere((e) => e.id == eventId);
    _controller.add(_events);
  }

  @override
  Future<Event?> findEventById(String eventId) async {
    try {
      return _events.firstWhere((e) => e.id == eventId);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<Event>> streamEvents() {
    return _controller.stream;
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class MockSessionRepository implements SessionRepository {
  final _controller = StreamController<List<Session>>.broadcast();
  List<Session> _sessions = [];

  void emit(List<Session> sessions) {
    _sessions = sessions;
    _controller.add(sessions);
  }

  void setSessions(List<Session> sessions) {
    _sessions = sessions;
  }

  @override
  Stream<List<Session>> streamSessions() {
    return _controller.stream;
  }

  @override
  Future<Session> createSession({
    required String title,
    String? eventId,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async {
    final session = Session(
      id: 'mock-session-${_sessions.length + 1}',
      eventId: eventId,
      title: title,
      sessionDate: sessionDate,
      records: records,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: actor,
      currentVersion: 1,
    );
    _sessions.add(session);
    _controller.add(_sessions);
    return session;
  }

  @override
  Future<List<Session>> loadSessions() async => _sessions;

  @override
  Future<Session?> findSessionById(String id) async {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      _sessions[index] = session;
    } else {
      _sessions.add(session);
    }
    _controller.add(_sessions);
    return session;
  }

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    _controller.add(_sessions);
  }

  @override
  Future<List<SessionVersion>> history(String sessionId) async {
    return [];
  }

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class MockAuthRepository implements AuthRepository {
  @override
  Future<User?> currentUser() async =>
      const User(id: 'test', email: 'test@test.com', displayName: 'Test User');

  @override
  Future<User> login(Credentials credentials) async =>
      throw UnimplementedError();

  @override
  Future<User> loginWithGoogle(GoogleAccount account) async =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<User> signup(Credentials credentials) async =>
      throw UnimplementedError();
}
