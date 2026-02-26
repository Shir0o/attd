import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../features/attendance/models/attendance_status.dart';
import 'session.dart';
import 'session_repository.dart';
import 'session_version.dart';
import 'session_record.dart';

class LocalJsonSessionRepository implements SessionRepository {
  LocalJsonSessionRepository({this.storagePath, List<Session>? seedSessions})
    : _seedSessions = seedSessions ?? [];

  final String? storagePath;
  final List<Session> _seedSessions;
  File? _file;

  // We add a 'versions' field to the JSON representation of the session for local storage,
  // even though it's not in the main Session model.
  // This is a simple way to store history without multiple files.
  // Map<SessionId, List<SessionVersion>>
  final Map<String, List<SessionVersion>> _historyCache = {};

  Future<File> get _storageFile async {
    if (_file != null) return _file!;

    final directory = storagePath != null
        ? Directory(storagePath!)
        : await getApplicationDocumentsDirectory();

    _file = File('${directory.path}/sessions.json');
    return _file!;
  }

  Future<List<Session>> _loadFromFile() async {
    final file = await _storageFile;
    if (!await file.exists()) {
      if (_seedSessions.isNotEmpty) {
        await _saveToFile(_seedSessions);
        return _seedSessions;
      }
      return [];
    }

    try {
      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(content);

      // Extract versions if they are embedded (implementation detail)
      // For this simple implementation, we might need a custom wrapper or just store them separately.
      // Let's store them in a separate file to be cleaner: sessions_history.json

      return jsonList.map((e) => Session.fromJson(e)).toList();
    } catch (e) {
      print('Error loading sessions: $e');
      return [];
    }
  }

  Future<void> _saveToFile(List<Session> sessions) async {
    final file = await _storageFile;
    final jsonList = sessions.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  // History file handling
  Future<File> get _historyFile async {
    final directory = storagePath != null
        ? Directory(storagePath!)
        : await getApplicationDocumentsDirectory();
    return File('${directory.path}/sessions_history.json');
  }

  Future<void> _loadHistory() async {
    if (_historyCache.isNotEmpty) return;

    final file = await _historyFile;
    if (!await file.exists()) return;

    try {
      final content = await file.readAsString();
      if (content.isEmpty) return;

      final Map<String, dynamic> jsonMap = jsonDecode(content);
      jsonMap.forEach((key, value) {
        if (value is List) {
          _historyCache[key] = value
              .map(
                (v) => SessionVersion(
                  sessionId: v['sessionId'],
                  version: v['version'],
                  snapshot: Session.fromJson(v['snapshot']),
                  recordedAt: DateTime.parse(v['recordedAt']),
                  actor: v['actor'],
                  isDeleted: v['isDeleted'],
                ),
              )
              .toList();
        }
      });
    } catch (e) {
      print('Error loading history: $e');
    }
  }

  Future<void> _saveHistory() async {
    final file = await _historyFile;
    // explicit toEncodable to help jsonEncode
    final Map<String, dynamic> exportMap = {};
    _historyCache.forEach((key, value) {
      exportMap[key] = value
          .map(
            (v) => {
              'sessionId': v.sessionId,
              'version': v.version,
              'snapshot': v.snapshot.toJson(),
              'recordedAt': v.recordedAt.toIso8601String(),
              'actor': v.actor,
              'isDeleted': v.isDeleted,
            },
          )
          .toList();
    });

    await file.writeAsString(jsonEncode(exportMap));
  }

  @override
  Future<void> refresh() async {
    _historyCache.clear();
    await loadSessions();
  }

  @override
  Future<List<Session>> loadSessions({bool includeDeleted = false}) async {
    final sessions = await _loadFromFile();
    // Sort by date descending
    sessions.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));

    if (includeDeleted) return sessions;
    return sessions.where((s) => !s.isDeleted).toList();
  }

  @override
  Future<Session> createSession({
    required String title,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async {
    final sessions = await _loadFromFile();
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

    sessions.add(session);
    await _saveToFile(sessions);

    // Save initial version
    await _loadHistory();
    final version = SessionVersion(
      sessionId: id,
      version: 1,
      snapshot: session,
      recordedAt: now,
      actor: actor,
      isDeleted: false,
    );
    _historyCache[id] = [version];
    await _saveHistory();

    return session;
  }

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    final sessions = await _loadFromFile();
    final now = DateTime.now();
    final nextVersion = session.currentVersion + 1;
    final nextSession = session.copyWith(
      currentVersion: nextVersion,
      updatedAt: now,
    );

    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      sessions[index] = nextSession;
    } else {
      sessions.add(nextSession);
    }
    await _saveToFile(sessions);

    // Save history
    await _loadHistory();
    // history entry
    final version = SessionVersion(
      sessionId: session.id,
      version: nextVersion,
      snapshot: nextSession,
      recordedAt: now,
      actor: actor,
      isDeleted: nextSession.isDeleted,
    );

    if (!_historyCache.containsKey(session.id)) {
      _historyCache[session.id] = [];
    }
    _historyCache[session.id]!.insert(0, version); // Newer first
    await _saveHistory();

    return nextSession;
  }

  @override
  Future<Session?> revertToPrevious(
    String sessionId, {
    required String actor,
  }) async {
    await _loadHistory();
    final history = _historyCache[sessionId];
    if (history == null || history.length < 2) return null;

    // Sort desc by version just in case
    history.sort((a, b) => b.version.compareTo(a.version));

    final previousVersion = history[1];
    final restoredSession = previousVersion.snapshot.copyWith(
      currentVersion: history.first.version + 1,
      updatedAt: DateTime.now(),
    );

    return saveSnapshot(restoredSession, actor: actor);
  }

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async {
    final sessions = await _loadFromFile();
    final source = sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => throw StateError('Session not found'),
    );

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
    await _loadHistory();
    final list = _historyCache[sessionId] ?? [];
    list.sort((a, b) => b.version.compareTo(a.version));
    return list;
  }
}
