import 'session.dart';
import 'session_record.dart';
import 'session_version.dart';

abstract class SessionRepository {
  Future<List<Session>> loadSessions();

  Stream<List<Session>> streamSessions();

  Future<Session?> findSessionById(String id);

  Future<Session> createSession({
    required String title,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  });

  Future<Session> saveSnapshot(Session session, {required String actor});

  Future<Session> duplicate(String sessionId, {required String actor});

  Future<void> deleteSession(String sessionId, {required String actor});

  Future<List<SessionVersion>> history(String sessionId);

  Future<void> refresh();
}
