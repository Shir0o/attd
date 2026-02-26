import 'package:uuid/uuid.dart';

import '../features/attendance/models/attendance_status.dart';
import 'session.dart';
import 'session_record.dart';
import 'session_version.dart';

abstract class SessionRepository {
  Future<List<Session>> loadSessions({bool includeDeleted = false});

  Stream<List<Session>> streamSessions({bool includeDeleted = false});

  Future<Session> createSession({
    required String title,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  });

  Future<Session> saveSnapshot(Session session, {required String actor});

  Future<Session?> revertToPrevious(String sessionId, {required String actor});

  Future<Session> duplicate(String sessionId, {required String actor});
  
  Future<void> deleteSession(String sessionId, {required String actor});

  Future<List<SessionVersion>> history(String sessionId);

  Future<void> refresh();
}

List<Session> buildSeedSessions() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final recordTime = now.subtract(const Duration(hours: 2));

  return [
    Session(
      id: const Uuid().v4(),
      title: 'Morning Standup',
      sessionDate: today,
      createdAt: recordTime,
      updatedAt: recordTime,
      createdBy: 'Automation',
      currentVersion: 1,
      records: [
        SessionRecord(
          attendee: 'Alana Rivera',
          status: AttendanceStatus.present,
          recordedAt: recordTime,
          recordedBy: 'Automation',
        ),
        SessionRecord(
          attendee: 'Priya Patel',
          status: AttendanceStatus.absent,
          recordedAt: recordTime,
          recordedBy: 'Automation',
        ),
      ],
    ),
    Session(
      id: const Uuid().v4(),
      title: 'Client Review',
      sessionDate: yesterday,
      createdAt: yesterday.subtract(const Duration(hours: 3)),
      updatedAt: yesterday.subtract(const Duration(hours: 3)),
      createdBy: 'Automation',
      currentVersion: 1,
      records: [
        SessionRecord(
          attendee: 'Minh Nguyen',
          status: AttendanceStatus.present,
          recordedAt: yesterday.subtract(const Duration(hours: 3)),
          recordedBy: 'Automation',
        ),
        SessionRecord(
          attendee: 'Anaya Patel',
          status: AttendanceStatus.present,
          recordedAt: yesterday.subtract(const Duration(hours: 3)),
          recordedBy: 'Automation',
        ),
        SessionRecord(
          attendee: 'Rishi Patel',
          status: AttendanceStatus.present,
          recordedAt: yesterday.subtract(const Duration(hours: 3)),
          recordedBy: 'Automation',
        ),
      ],
    ),
  ];
}
