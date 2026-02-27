import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'session.dart';
import 'session_repository.dart';
import 'session_version.dart';
import 'session_record.dart';

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
    final backupFile = File('${file.path}.bak');

    if (!await file.exists()) {
      if (await backupFile.exists()) {
        await backupFile.copy(file.path);
      } else {
        return [];
      }
    }

    try {
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final List<dynamic> jsonList = jsonDecode(content);
      final sessions = jsonList.map((e) => Session.fromJson(e)).toList();
      _sessionsCache = sessions;
      return sessions;
    } catch (e) {
      print('Main storage corrupted, attempting recovery: $e');
      // Recovery Path 1: Try the .bak file
      try {
        if (await backupFile.exists()) {
          final backupContent = await backupFile.readAsString();
          final List<dynamic> jsonList = jsonDecode(backupContent);
          print('Successfully recovered from .bak file');
          return jsonList.map((e) => Session.fromJson(e)).toList();
        }
      } catch (backupError) {
        print('Backup recovery failed: $backupError');
      }

      // Recovery Path 2: Try the latest snapshots from history
      try {
        await _loadHistory();
        if (_historyCache.isNotEmpty) {
          print('Attempting reconstruction from history snapshots');
          final recovered = _historyCache.values
              .map((versions) => versions.first.snapshot)
              .toList();
          return recovered;
        }
      } catch (historyError) {
        print('History recovery failed: $historyError');
      }

      return [];
    }
  }

  Future<void> _saveToFile(List<Session> sessions) async {
    _sessionsCache = sessions;
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
        await file.rename(backupFile.path);
      }

      // 3. Move temp to current (Atomic rename)
      await tempFile.rename(file.path);
    } catch (e) {
      print('Error during atomic save: $e');
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
            },
          )
          .toList();
    });

    await file.writeAsString(jsonEncode(exportMap));
  }

  @override
  Future<void> refresh() async {
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
        final sessions = _sessionsCache ?? [];
        // Sort by date descending
        sessions.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
        controller.add(sessions);
      }
    }

    // If we have a cache, emit it immediately.
    // If not, loadSessions will be called by _init or similar and trigger the broadcast stream.
    if (_sessionsCache != null) {
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
    if (_sessionsCache != null) {
      // Sort copy to avoid mutating cache incorrectly if sort is needed
      final sorted = List<Session>.from(_sessionsCache!);
      sorted.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
      _controller.add(sorted);
      return sorted;
    }

    final sessions = await _loadFromFile();
    // Sort by date descending
    sessions.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));

    _controller.add(sessions);
    return sessions;
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
    final sessions = await _loadFromFile();
    final initialLength = sessions.length;
    sessions.removeWhere((s) => s.id == sessionId);

    if (sessions.length < initialLength) {
      await _saveToFile(sessions);
      _controller.add(await loadSessions());

      // Clean up history for this session
      _historyCache.remove(sessionId);
      await _saveHistory();
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
