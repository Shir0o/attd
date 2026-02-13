import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../features/attendance/models/attendance_status.dart';
import 'session.dart';
import 'session_record.dart';
import 'session_version.dart';

abstract class SessionRepository {
  Future<List<Session>> loadSessions({bool includeDeleted = false});

  Future<Session> createSession({
    required String title,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  });

  Future<Session> saveSnapshot(Session session, {required String actor});

  Future<Session?> revertToPrevious(String sessionId, {required String actor});

  Future<Session> duplicate(String sessionId, {required String actor});

  Future<List<SessionVersion>> history(String sessionId);
}

class FirestoreSessionRepository implements SessionRepository {
  FirestoreSessionRepository({
    FirebaseFirestore? firestore,
    List<Session>? seedSessions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _seedSessions = seedSessions ?? [];

  final FirebaseFirestore _firestore;
  final List<Session> _seedSessions;

  CollectionReference<Map<String, dynamic>> get _sessionsRef =>
      _firestore.collection('sessions');

  CollectionReference<Map<String, dynamic>> _versionsRef(String sessionId) =>
      _sessionsRef.doc(sessionId).collection('versions');

  @override
  Future<List<Session>> loadSessions({bool includeDeleted = false}) async {
    Query<Map<String, dynamic>> query = _sessionsRef.orderBy(
      'sessionDate',
      descending: true,
    );

    if (!includeDeleted) {
      query = query.where('isDeleted', isEqualTo: false);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isEmpty && _seedSessions.isNotEmpty) {
      // Seed if empty
      final batch = _firestore.batch();
      for (final session in _seedSessions) {
        await createSession(
          title: session.title,
          sessionDate: session.sessionDate,
          actor: session.createdBy,
          records: session.records,
          batch: batch,
        );
      }
      await batch.commit();

      // Re-fetch after seeding
      final newSnapshot = await query.get();
      return newSnapshot.docs
          .map((doc) => Session.fromJson(doc.data()))
          .toList();
    }

    return snapshot.docs.map((doc) => Session.fromJson(doc.data())).toList();
  }

  @override
  Future<Session> createSession({
    required String title,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
    WriteBatch? batch,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    final session = Session(
      id: id,
      title: title,
      sessionDate: sessionDate,
      records: records,
      createdAt: now,
      updatedAt: now,
      createdBy: actor,
      isDeleted: false,
      currentVersion: 1,
    );

    final writeBatch = batch ?? _firestore.batch();

    // 1. Create session document
    writeBatch.set(_sessionsRef.doc(id), session.toJson());

    // 2. Create initial version
    final versionParam = {
      'sessionId': id,
      'version': 1,
      'snapshot': session.toJson(), // Store full snapshot
      'recordedAt': now.toIso8601String(),
      'actor': actor,
      'isDeleted': false,
    };

    writeBatch.set(_versionsRef(id).doc('1'), versionParam);

    if (batch == null) {
      await writeBatch.commit();
    }
    return session;
  }

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    final now = DateTime.now();
    final nextVersion = session.currentVersion + 1;
    final nextSession = session.copyWith(
      currentVersion: nextVersion,
      updatedAt: now,
    );

    final batch = _firestore.batch();

    // 1. Update session document
    batch.set(_sessionsRef.doc(session.id), nextSession.toJson());

    // 2. Add new version
    batch.set(_versionsRef(session.id).doc(nextVersion.toString()), {
      'sessionId': session.id,
      'version': nextVersion,
      'snapshot': nextSession.toJson(),
      'recordedAt': now.toIso8601String(),
      'actor': actor,
      'isDeleted': nextSession.isDeleted,
    });

    await batch.commit();
    return nextSession;
  }

  Future<Session?> _fetchSession(String sessionId) async {
    final doc = await _sessionsRef.doc(sessionId).get();
    if (!doc.exists) return null;
    return Session.fromJson(doc.data()!);
  }

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async {
    final source = await _fetchSession(sessionId);
    if (source == null) throw StateError('Session not found');

    final now = DateTime.now();
    final newRecords = source.records
        .map((r) => r.copyWith(recordedAt: now, recordedBy: actor))
        .toList();

    return createSession(
      title: '${source.title} (redo)',
      sessionDate: now,
      actor: actor,
      records: newRecords,
    );
  }

  @override
  Future<List<SessionVersion>> history(String sessionId) async {
    final snapshot = await _versionsRef(
      sessionId,
    ).orderBy('version', descending: true).get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return SessionVersion(
        sessionId: data['sessionId'] as String,
        version: data['version'] as int,
        snapshot: Session.fromJson(data['snapshot'] as Map<String, dynamic>),
        recordedAt: DateTime.parse(data['recordedAt'] as String),
        actor: data['actor'] as String,
        isDeleted: data['isDeleted'] as bool,
      );
    }).toList();
  }

  @override
  Future<Session?> revertToPrevious(
    String sessionId, {
    required String actor,
  }) async {
    // 1. Get recent versions
    final versionsSnapshot = await _versionsRef(
      sessionId,
    ).orderBy('version', descending: true).limit(2).get();

    if (versionsSnapshot.docs.length < 2) return null;

    final previousDoc = versionsSnapshot.docs[1];
    final previousData = previousDoc.data();
    final previousSnapshot = Session.fromJson(
      previousData['snapshot'] as Map<String, dynamic>,
    );

    // 2. Create new version from previous state
    final currentDoc = versionsSnapshot.docs[0];
    final currentVersion = currentDoc.data()['version'] as int;

    final restoredSession = previousSnapshot.copyWith(
      currentVersion: currentVersion + 1,
      updatedAt: DateTime.now(),
    );

    await saveSnapshot(restoredSession, actor: actor);
    return restoredSession;
  }
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
