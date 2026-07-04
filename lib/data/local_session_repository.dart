import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/logging/app_logger.dart';
import 'session.dart';
import 'session_repository.dart';
import 'session_version.dart';
import 'session_record.dart';

final _log = AppLogger('SessionRepository');

class LocalJsonSessionRepository implements SessionRepository {
  LocalJsonSessionRepository({this.storagePath}) {
    _controller = StreamController<List<Session>>.broadcast(
      onListen: () {
        loadSessions().then((sessions) {
          if (!_controller.isClosed) {
            _controller.add(sessions);
          }
        });
      },
    );
  }

  final String? storagePath;
  File? _file;
  late final StreamController<List<Session>> _controller;

  // We add a 'versions' field to the JSON representation of the session for local storage,
  // even though it's not in the main Session model.
  // This is a simple way to store history without multiple files.
  // Map<SessionId, List<SessionVersion>>
  final Map<String, List<SessionVersion>> _historyCache = {};
  List<Session>? _sessionsCache;
  List<Session>? _activeSessionsCache;

  Future<File> get _storageFile async {
    if (_file != null) return _file!;

    final directory = storagePath != null
        ? Directory(storagePath!)
        : await getApplicationDocumentsDirectory();

    _file = File('${directory.path}/sessions.json');
    return _file!;
  }

  Future<List<Session>> _loadFromFile() async {
    final decoded = await _loadRawSessions();
    _sessionsCache = decoded;
    _activeSessionsCache = decoded.where((s) => s.deletedAt == null).toList()
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
    return _activeSessionsCache!;
  }

  Future<void> _saveToFile(List<Session> sessions) async {
    _sessionsCache = sessions;
    _activeSessionsCache = sessions.where((s) => s.deletedAt == null).toList()
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
    final file = await _storageFile;
    final tempFile = File('${file.path}.tmp');
    final backupFile = File('${file.path}.bak');

    try {
      final jsonList = sessions.map((e) => e.toJson()).toList();
      final content = jsonEncode(jsonList);

      // 1. Write to temp file
      await tempFile.writeAsString(content);

      // 2. Rotate current to backup
      if (await file.exists()) {
        if (await backupFile.exists()) {
          await backupFile.delete();
        }
        await file.rename(backupFile.path);
      }

      // 3. Move temp to current (Atomic rename)
      await tempFile.rename(file.path);
    } catch (e, st) {
      _log.error('Error during atomic save', e, st);
      // If we failed, try to restore current from backup if possible
      if (await backupFile.exists() && !await file.exists()) {
        await backupFile.copy(file.path);
      }
    }
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
                ),
              )
              .toList();
        }
      });
    } catch (e, st) {
      _log.error('Error loading history', e, st);
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
            },
          )
          .toList();
    });

    await file.writeAsString(jsonEncode(exportMap));
  }

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {
    final sessions = await _loadFromFile();
    bool changed = false;

    List<Session> migrateSessionList(List<Session> list) {
      return list.map((session) {
        final updatedRecords = session.records.map((record) {
          if (record.memberId == null && nameToIdMap.containsKey(record.attendee)) {
            changed = true;
            return record.copyWith(memberId: nameToIdMap[record.attendee]);
          }
          return record;
        }).toList();
        return session.copyWith(records: updatedRecords);
      }).toList();
    }

    final updatedSessions = migrateSessionList(sessions);
    if (changed) {
      await _saveToFile(updatedSessions);
    }

    // Also migrate history
    await _loadHistory();
    bool anyHistoryChanged = false;
    _historyCache.forEach((sessionId, versions) {
      for (int i = 0; i < versions.length; i++) {
        final version = versions[i];
        final session = version.snapshot;
        bool versionChanged = false;
        final updatedRecords = session.records.map((record) {
          if (record.memberId == null && nameToIdMap.containsKey(record.attendee)) {
            versionChanged = true;
            return record.copyWith(memberId: nameToIdMap[record.attendee]);
          }
          return record;
        }).toList();

        if (versionChanged) {
          anyHistoryChanged = true;
          versions[i] = SessionVersion(
            sessionId: version.sessionId,
            version: version.version,
            snapshot: session.copyWith(records: updatedRecords),
            recordedAt: version.recordedAt,
            actor: version.actor,
          );
        }
      }
    });

    if (anyHistoryChanged) {
      await _saveHistory();
    }

    if (changed || anyHistoryChanged) {
      await refresh();
    }
  }

  Future<List<Session>> _loadRawSessions() async {
    final file = await _storageFile;
    if (!await file.exists()) {
      final backupFile = File('${file.path}.bak');
      if (await backupFile.exists()) {
        _log.warning('Main sessions file missing, attempting recovery from backup');
        try {
          final backupContent = await backupFile.readAsString();
          if (backupContent.isNotEmpty) {
            final List<dynamic> jsonList = jsonDecode(backupContent);
            final sessions = jsonList.map((e) => Session.fromJson(e)).toList();
            await backupFile.copy(file.path);
            return sessions;
          }
        } catch (backupError, backupSt) {
          _log.error('Failed to recover sessions from backup file', backupError, backupSt);
        }
      }
      return [];
    }

    try {
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => Session.fromJson(e)).toList();
    } catch (e, st) {
      _log.error('Error loading raw sessions, attempting recovery from backup', e, st);
      final backupFile = File('${file.path}.bak');
      if (await backupFile.exists()) {
        try {
          final backupContent = await backupFile.readAsString();
          if (backupContent.isNotEmpty) {
            final List<dynamic> jsonList = jsonDecode(backupContent);
            final sessions = jsonList.map((e) => Session.fromJson(e)).toList();
            // Restore main file from backup
            await backupFile.copy(file.path);
            _log.info('Successfully recovered raw sessions from backup');
            return sessions;
          }
        } catch (backupError, backupSt) {
          _log.error('Failed to recover sessions from backup file', backupError, backupSt);
        }
      }
      return [];
    }
  }

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {
    final allSessions = await _loadRawSessions();
    bool changed = false;

    final prunedSessions = allSessions.where((s) {
      if (s.deletedAt != null && s.deletedAt!.isBefore(threshold)) {
        changed = true;
        return false;
      }
      return true;
    }).toList();

    if (changed) {
      await _saveToFile(prunedSessions);
      
      // Also clean up history for pruned sessions
      final prunedIds = allSessions
          .where((s) => s.deletedAt != null && s.deletedAt!.isBefore(threshold))
          .map((s) => s.id)
          .toSet();
      
      if (prunedIds.isNotEmpty) {
        await _loadHistory();
        bool historyChanged = false;
        for (final id in prunedIds) {
          if (_historyCache.containsKey(id)) {
            _historyCache.remove(id);
            historyChanged = true;
          }
        }
        if (historyChanged) {
          await _saveHistory();
        }
      }
    }
  }

  @override
  Future<void> refresh() async {
    _sessionsCache = null;
    _activeSessionsCache = null;
    _historyCache.clear();
    final sessions = await loadSessions();
    _controller.add(sessions);
  }

  @override
  Stream<List<Session>> streamSessions() {
    // We wrap the stream to ensure the current cache is emitted immediately
    // to every new listener, similar to a BehaviorSubject.
    final controller = StreamController<List<Session>>();

    void emit() {
      if (!controller.isClosed) {
        final sessions = List<Session>.from(_activeSessionsCache ?? []);
        controller.add(sessions);
      }
    }

    // If we have a cache, emit it immediately.
    // If not, loadSessions will be called by _init or similar and trigger the broadcast stream.
    if (_activeSessionsCache != null) {
      emit();
    } else {
      // Trigger a load if we don't have anything yet
      loadSessions().then((_) => emit());
    }

    // Listen to the master broadcast stream for future updates
    final subscription = _controller.stream.listen((sessions) {
      if (!controller.isClosed) {
        controller.add(sessions);
      }
    });

    controller.onCancel = () => subscription.cancel();

    return controller.stream;
  }

  @override
  Future<List<Session>> loadSessions() async {
    if (_activeSessionsCache != null) {
      _controller.add(_activeSessionsCache!);
      return _activeSessionsCache!;
    }

    final sessions = await _loadFromFile();
    _controller.add(sessions);
    return sessions;
  }

  Future<List<Session>> fetchAllSessions() async {
    return _loadRawSessions();
  }

  Future<void> saveSessions(List<Session> sessions) async {
    await _saveToFile(sessions);
    await refresh();
  }


  @override
  Future<Session?> findSessionById(String id) async {
    if (_sessionsCache != null) {
      try {
        return _sessionsCache!.firstWhere((s) => s.id == id);
      } catch (_) {
        return null;
      }
    }
    final sessions = await loadSessions();
    try {
      return sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Session> createSession({
    required String title,
    String? eventId,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async {
    final sessions = await _loadFromFile();
    final id = const Uuid().v4();
    final now = DateTime.now();

    final session = Session(
      id: id,
      eventId: eventId,
      title: title,
      sessionDate: sessionDate,
      records: records,
      createdAt: now,
      updatedAt: now,
      createdBy: actor,
      currentVersion: 1,
    );

    sessions.add(session);
    await _saveToFile(sessions);
    _controller.add(await loadSessions());

    // Save initial version
    await _loadHistory();
    final version = SessionVersion(
      sessionId: id,
      version: 1,
      snapshot: session,
      recordedAt: now,
      actor: actor,
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
    _controller.add(await loadSessions());

    // Save history
    await _loadHistory();
    // history entry
    final version = SessionVersion(
      sessionId: session.id,
      version: nextVersion,
      snapshot: nextSession,
      recordedAt: now,
      actor: actor,
    );

    if (!_historyCache.containsKey(session.id)) {
      _historyCache[session.id] = [];
    }
    _historyCache[session.id]!.insert(0, version); // Newer first
    await _saveHistory();

    return nextSession;
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
      eventId: source.eventId,
      sessionDate: now,
      actor: actor,
      records: newRecords,
    );
  }

  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {
    final allSessions = await _loadRawSessions();
    final index = allSessions.indexWhere((s) => s.id == sessionId);

    if (index != -1) {
      final now = DateTime.now();
      allSessions[index] = allSessions[index].copyWith(
        deletedAt: now,
        updatedAt: now,
      );
      await _saveToFile(allSessions);
      // _saveToFile already updates _sessionsCache and _activeSessionsCache
      _controller.add(await loadSessions());
    }
  }

  @override
  Future<List<SessionVersion>> history(String sessionId) async {
    await _loadHistory();
    final list = _historyCache[sessionId] ?? [];
    list.sort((a, b) => b.version.compareTo(a.version));
    return list;
  }
}
