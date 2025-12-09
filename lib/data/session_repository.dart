import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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

class LocalSessionRepository implements SessionRepository {
  LocalSessionRepository({
    this.customFactory,
    this.dbPathProvider,
    DateTime Function()? clock,
    List<Session>? seedSessions,
  }) : _clock = clock ?? DateTime.now,
       _seedSessions = seedSessions ?? [] {
    _initialization = _init();
  }

  final DatabaseFactory? customFactory;
  final Future<String> Function()? dbPathProvider;
  final DateTime Function() _clock;
  final List<Session> _seedSessions;
  late final Future<Database> _database;
  late final Future<void> _initialization;

  Future<void> _init() async {
    final dbPath = await (dbPathProvider?.call() ?? _defaultDbPath());
    _database = _openDatabase(dbPath);
    final db = await _database;
    await db.execute(
      'CREATE TABLE IF NOT EXISTS sessions ('
      'id TEXT PRIMARY KEY,'
      'title TEXT NOT NULL,'
      'session_date TEXT NOT NULL,'
      'created_at TEXT NOT NULL,'
      'updated_at TEXT NOT NULL,'
      'created_by TEXT NOT NULL,'
      'current_version INTEGER NOT NULL,'
      'is_deleted INTEGER NOT NULL,'
      'latest_payload TEXT NOT NULL'
      ')',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS session_versions ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT,'
      'session_id TEXT NOT NULL,'
      'version INTEGER NOT NULL,'
      'payload TEXT NOT NULL,'
      'recorded_at TEXT NOT NULL,'
      'actor TEXT NOT NULL,'
      'is_deleted INTEGER NOT NULL,'
      'FOREIGN KEY(session_id) REFERENCES sessions(id)'
      ')',
    );

    final existing =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM sessions'),
        ) ??
        0;
    if (existing == 0 && _seedSessions.isNotEmpty) {
      for (final session in _seedSessions) {
        await _insertSession(db, session, actor: session.createdBy);
      }
    }
  }

  Future<String> _defaultDbPath() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return p.join(directory.path, 'sessions.db');
  }

  Future<Database> _openDatabase(String path) async {
    DatabaseFactory primary = customFactory ?? databaseFactory;

    try {
      return primary.openDatabase(path);
    } catch (_) {
      sqfliteFfiInit();
      final fallback = databaseFactoryFfi;
      return fallback.openDatabase(path);
    }
  }

  @override
  Future<Session> createSession({
    required String title,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async {
    await _initialization;
    final db = await _database;
    final now = _clock();
    final session = Session(
      id: const Uuid().v4(),
      title: title,
      sessionDate: sessionDate,
      records: records,
      createdAt: now,
      updatedAt: now,
      createdBy: actor,
      isDeleted: false,
      currentVersion: 1,
    );
    await _insertSession(db, session, actor: actor);
    return session;
  }

  Future<void> _insertSession(
    Database db,
    Session session, {
    required String actor,
  }) async {
    await db.insert('sessions', {
      'id': session.id,
      'title': session.title,
      'session_date': session.sessionDate.toIso8601String(),
      'created_at': session.createdAt.toIso8601String(),
      'updated_at': session.updatedAt.toIso8601String(),
      'created_by': session.createdBy,
      'current_version': session.currentVersion,
      'is_deleted': session.isDeleted ? 1 : 0,
      'latest_payload': jsonEncode(session.toJson()),
    });

    await db.insert('session_versions', {
      'session_id': session.id,
      'version': session.currentVersion,
      'payload': jsonEncode(session.toJson()),
      'recorded_at': session.updatedAt.toIso8601String(),
      'actor': actor,
      'is_deleted': session.isDeleted ? 1 : 0,
    });
  }

  Future<void> _saveVersion(
    Database db,
    Session session, {
    required String actor,
  }) async {
    await db.update(
      'sessions',
      {
        'title': session.title,
        'session_date': session.sessionDate.toIso8601String(),
        'updated_at': session.updatedAt.toIso8601String(),
        'current_version': session.currentVersion,
        'is_deleted': session.isDeleted ? 1 : 0,
        'latest_payload': jsonEncode(session.toJson()),
      },
      where: 'id = ?',
      whereArgs: [session.id],
    );

    await db.insert('session_versions', {
      'session_id': session.id,
      'version': session.currentVersion,
      'payload': jsonEncode(session.toJson()),
      'recorded_at': session.updatedAt.toIso8601String(),
      'actor': actor,
      'is_deleted': session.isDeleted ? 1 : 0,
    });
  }

  @override
  Future<List<Session>> loadSessions({bool includeDeleted = false}) async {
    await _initialization;
    final db = await _database;
    final rows = await db.query(
      'sessions',
      orderBy: 'session_date DESC',
      where: includeDeleted ? null : 'is_deleted = 0',
    );
    return rows
        .map(
          (row) => Session.fromJson(
            jsonDecode(row['latest_payload'] as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    await _initialization;
    final db = await _database;
    final now = _clock();
    final next = session.copyWith(
      currentVersion: session.currentVersion + 1,
      updatedAt: now,
    );
    await _saveVersion(db, next, actor: actor);
    return next;
  }

  Future<Session> _getLatest(String sessionId) async {
    final db = await _database;
    final rows = await db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Session not found');
    return Session.fromJson(
      jsonDecode(rows.first['latest_payload'] as String)
          as Map<String, dynamic>,
    );
  }

  @override
  Future<Session?> revertToPrevious(
    String sessionId, {
    required String actor,
  }) async {
    await _initialization;
    final db = await _database;
    final versions = await db.query(
      'session_versions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'version DESC',
      limit: 2,
    );
    if (versions.length < 2) {
      return null;
    }

    final previous = versions[1];
    final snapshot = Session.fromJson(
      jsonDecode(previous['payload'] as String) as Map<String, dynamic>,
    );
    final restored = snapshot.copyWith(
      updatedAt: _clock(),
      currentVersion: (versions.first['version'] as int) + 1,
    );
    await _saveVersion(db, restored, actor: actor);
    return restored;
  }

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async {
    await _initialization;
    final latest = await _getLatest(sessionId);
    final now = _clock();
    final cloned = latest.copyWith(
      id: const Uuid().v4(),
      title: '${latest.title} (redo)',
      sessionDate: now,
      createdAt: now,
      updatedAt: now,
      createdBy: actor,
      currentVersion: 1,
      isDeleted: false,
      records: latest.records
          .map((record) => record.copyWith(recordedAt: now, recordedBy: actor))
          .toList(),
    );

    await _initialization;
    final db = await _database;
    await _insertSession(db, cloned, actor: actor);
    return cloned;
  }

  @override
  Future<List<SessionVersion>> history(String sessionId) async {
    await _initialization;
    final db = await _database;
    final rows = await db.query(
      'session_versions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'version DESC',
    );
    return rows
        .map(
          (row) => SessionVersion(
            sessionId: row['session_id'] as String,
            version: row['version'] as int,
            snapshot: Session.fromJson(
              jsonDecode(row['payload'] as String) as Map<String, dynamic>,
            ),
            recordedAt: DateTime.parse(row['recorded_at'] as String),
            actor: row['actor'] as String,
            isDeleted: (row['is_deleted'] as int) == 1,
          ),
        )
        .toList();
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
          attendee: 'Mateo Rivera',
          status: AttendanceStatus.partial,
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
