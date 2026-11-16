import 'dart:async';

import 'package:flutter/material.dart';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';

/// Event repository that replays its list to every listener and re-emits
/// after an update, like the real one.
class FakeCheckOnEventRepository extends EventRepository {
  FakeCheckOnEventRepository(List<Event> events) : events = [...events];

  List<Event> events;
  final updated = <Event>[];
  final _changes = StreamController<List<Event>>.broadcast();

  @override
  Stream<List<Event>> streamEvents() async* {
    yield [...events];
    yield* _changes.stream;
  }

  @override
  Future<void> updateEvent(Event event) async {
    updated.add(event);
    events = [for (final e in events) e.id == event.id ? event : e];
    _changes.add([...events]);
  }

  @override
  Future<void> createEvent(Event event) async {}
  @override
  Future<void> deleteEvent(String eventId) async {}
  @override
  Future<Event?> findEventById(String eventId) async => null;
  @override
  Future<void> refresh() async {}
  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class FakeCheckOnSessionRepository extends SessionRepository {
  FakeCheckOnSessionRepository(this.sessions);

  List<Session> sessions;

  @override
  Future<List<Session>> loadSessions() async => sessions;
  @override
  Stream<List<Session>> streamSessions() => Stream.value(sessions);
  @override
  Future<Session?> findSessionById(String id) async {
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

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
  Future<Session> saveSnapshot(Session session,
          {required String actor}) async =>
      session;
  @override
  Future<Session> duplicate(String sessionId, {required String actor}) =>
      throw UnimplementedError();
  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {}
  @override
  Future<List<SessionVersion>> history(String sessionId) async => [];
  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class FakeCheckOnAttendanceRepository extends AttendanceRepository {
  FakeCheckOnAttendanceRepository(List<Member> members)
      : families = [
          for (final m in members)
            Family(id: 'f-${m.id}', displayName: m.displayName, members: [m]),
        ];

  List<Family> families;

  @override
  Future<List<Family>> fetchFamilies() async => families;
  @override
  Stream<List<Family>> streamFamilies() => Stream.value(families);
  @override
  Future<void> saveFamilies(List<Family> families) async {}
  @override
  Future<Family> addFamily(String displayName,
          {bool isAutoSingleton = false}) async =>
      throw UnimplementedError();
  @override
  Future<Family> addMember(String familyId, Member member) async =>
      throw UnimplementedError();
  @override
  Future<void> refresh() async {}
  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

final checkOnStart = DateTime(2026, 1, 7);

Member checkOnMember(String id, String name) =>
    Member(id: id, displayName: name);

Event checkOnEvent({String id = 'e1', String title = 'Study'}) => Event(
      id: id,
      title: title,
      time: const TimeOfDay(hour: 19, minute: 0),
      frequency: 'Weekly',
      createdAt: DateTime(2026, 1, 1),
    );

/// One session per pattern character, oldest first: `x` present, `.` absent.
List<Session> checkOnSessions(
  Map<Member, String> patterns, {
  String eventId = 'e1',
  String title = 'Study',
}) {
  final n = patterns.values.first.length;
  return [
    for (var i = 0; i < n; i++)
      Session(
        id: '$eventId-s$i',
        eventId: eventId,
        title: title,
        sessionDate: checkOnStart.add(Duration(days: 7 * i)),
        records: [
          for (final e in patterns.entries)
            SessionRecord(
              memberId: e.key.id,
              attendee: e.key.displayName,
              status: e.value[i] == 'x'
                  ? AttendanceStatus.present
                  : AttendanceStatus.absent,
              recordedAt: checkOnStart,
              recordedBy: 'user',
            ),
        ],
        createdAt: checkOnStart,
        updatedAt: checkOnStart,
        createdBy: 'user',
      ),
  ];
}
