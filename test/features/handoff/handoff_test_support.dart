import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/handoff/data/handoff_service.dart';
import 'package:attendance_tracker/features/handoff/data/handoff_sharer.dart';
import 'package:attendance_tracker/features/handoff/domain/handoff_file.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:flutter/material.dart' show TimeOfDay;

/// A sharer that records what would have gone to the share sheet.
class FakeSharer extends HandoffSharer {
  final sent = <({HandoffDocument document, String fileName, String text})>[];
  bool fail = false;

  @override
  Future<void> send({
    required HandoffDocument document,
    required String fileName,
    required String text,
  }) async {
    if (fail) throw StateError('share sheet unavailable');
    sent.add((document: document, fileName: fileName, text: text));
  }
}

class FakeSessions extends SessionRepository {
  FakeSessions([List<Session>? sessions]) : sessions = sessions ?? [];

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
  Future<Session> saveSnapshot(Session session, {required String actor}) async =>
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

class FakeAttendance extends AttendanceRepository {
  @override
  Future<List<Family>> fetchFamilies() async => [];
  @override
  Stream<List<Family>> streamFamilies() => Stream.value([]);
  @override
  Future<void> saveFamilies(List<Family> families) async {}
  @override
  Future<Family> addFamily(String displayName,
          {bool isAutoSingleton = false}) =>
      throw UnimplementedError();
  @override
  Future<Family> addMember(String familyId, Member member) =>
      throw UnimplementedError();
  @override
  Future<void> refresh() async {}
  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class FakeEvents extends EventRepository {
  @override
  Future<void> createEvent(Event event) async {}
  @override
  Future<void> updateEvent(Event event) async {}
  @override
  Future<void> deleteEvent(String eventId) async {}
  @override
  Future<Event?> findEventById(String eventId) async => null;
  @override
  Stream<List<Event>> streamEvents() => Stream.value([]);
  @override
  Future<void> refresh() async {}
  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

/// A service whose repository work is scripted by the test.
class FakeHandoffService extends HandoffService {
  FakeHandoffService()
      : super(
          attendanceRepository: FakeAttendance(),
          eventRepository: FakeEvents(),
          sessionRepository: FakeSessions(),
        );

  final removed = <Event>[];
  final received = <HandoffRoster>[];
  final applied = <HandoffResult>[];
  final previewed = <HandoffResult>[];

  /// When set, [preview] and [apply] refuse with this message.
  String? refuse;
  ResultImportOutcome outcome = const ResultImportOutcome(
    sessionCreated: true,
    changed: true,
    unknownMemberMarks: 0,
  );
  Object? applyError;
  Object? receiveError;

  @override
  Future<Event> receive(HandoffRoster doc) async {
    final error = receiveError;
    if (error != null) throw error;
    received.add(doc);
    return Event(
      id: doc.localEventId,
      title: doc.eventTitle,
      time: const TimeOfDay(hour: 0, minute: 0),
      frequency: 'One-time',
      oneTimeDate: doc.sessionDate,
      handoffEventId: doc.eventId,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<void> remove(Event event) async => removed.add(event);

  @override
  Future<ResultPreview> preview(HandoffResult result) async {
    previewed.add(result);
    final message = refuse;
    if (message != null) throw HandoffFormatException(message);
    return ResultPreview(
      result: result,
      event: Event(
        id: result.eventId,
        title: 'Sunday Service',
        time: const TimeOfDay(hour: 9, minute: 0),
        frequency: 'Weekly',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  }

  @override
  Future<ResultImportOutcome> apply(HandoffResult result) async {
    final error = applyError;
    if (error != null) throw error;
    applied.add(result);
    return outcome;
  }
}

Event handedOffEvent({String title = 'Sunday Service'}) => Event(
      id: 'handoff:ev-1',
      title: title,
      time: const TimeOfDay(hour: 0, minute: 0),
      frequency: 'One-time',
      oneTimeDate: DateTime(2026, 11, 15),
      memberIds: const ['handoff:m1', 'handoff:m2'],
      handoffEventId: 'ev-1',
      createdAt: DateTime(2026, 11, 10),
    );

Session markedSession() => Session(
      id: 's1',
      eventId: 'handoff:ev-1',
      title: 'Sunday Service',
      sessionDate: DateTime(2026, 11, 15),
      createdAt: DateTime(2026, 11, 15),
      updatedAt: DateTime(2026, 11, 15),
      createdBy: 'Helper',
      records: [
        SessionRecord(
          memberId: 'handoff:m1',
          attendee: 'Alice Johnson',
          status: AttendanceStatus.present,
          recordedAt: DateTime.utc(2026, 11, 15, 10),
          recordedBy: 'Helper',
        ),
        SessionRecord(
          memberId: 'handoff:m2',
          attendee: 'Bob Smith',
          status: AttendanceStatus.absent,
          recordedAt: DateTime.utc(2026, 11, 15, 10, 1),
          recordedBy: 'Helper',
        ),
        SessionRecord(
          attendee: 'Visitor Vic',
          status: AttendanceStatus.present,
          recordedAt: DateTime.utc(2026, 11, 15, 10, 2),
          recordedBy: 'Helper',
        ),
      ],
    );
