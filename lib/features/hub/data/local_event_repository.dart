import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:path_provider/path_provider.dart';

import '../domain/event.dart';
import 'event_repository.dart';

class LocalJsonEventRepository implements EventRepository {
  LocalJsonEventRepository({this.storagePath});

  final String? storagePath;
  File? _file;
  final _controller = StreamController<List<Event>>.broadcast();
  List<Event> _cache = [];
  bool _initialized = false;

  Future<File> get _storageFile async {
    if (_file != null) return _file!;

    final directory =
        storagePath != null
            ? Directory(storagePath!)
            : await getApplicationDocumentsDirectory();

    _file = File('${directory.path}/events.json');
    return _file!;
  }

  Future<List<Event>> _loadRawEvents() async {
    final file = await _storageFile;
    if (!await file.exists()) return [];

    try {
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => Event.fromJson(e)).toList();
    } catch (e) {
      print('Error loading raw events: $e');
      return [];
    }
  }

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {
    final allEvents = await _loadRawEvents();
    bool changed = false;

    final prunedEvents = allEvents.where((e) {
      if (e.deletedAt != null && e.deletedAt!.isBefore(threshold)) {
        changed = true;
        return false;
      }
      return true;
    }).toList();

    if (changed) {
      _cache = prunedEvents;
      await _save();
    }
  }

  @override
  Future<void> refresh() async {
    _initialized = false;
    await _init();
  }

  Future<void> _init() async {
    if (_initialized) {
      _controller.add(_cache.where((e) => e.deletedAt == null).toList());
      return;
    }

    final decoded = await _loadRawEvents();
    _cache = decoded;

    _controller.add(_cache.where((e) => e.deletedAt == null).toList());
    _initialized = true;
  }

  Future<void> _save() async {
    final file = await _storageFile;
    final tempFile = File('${file.path}.tmp');
    final backupFile = File('${file.path}.bak');

    try {
      final jsonList = _cache.map((e) => e.toJson()).toList();
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
      print('Error during events save: $e');
      // Restore from backup if possible
      if (await backupFile.exists() && !await file.exists()) {
        await backupFile.copy(file.path);
      }
    }
    
    _controller.add(_cache.where((e) => e.deletedAt == null).toList());
  }

  @override
  Future<void> createEvent(Event event) async {
    await _init();
    final now = DateTime.now();
    final newEvent = event.copyWith(updatedAt: now);
    _cache.insert(0, newEvent); // Add to top
    await _save();
  }

  @override
  Future<void> updateEvent(Event event) async {
    await _init();
    final index = _cache.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      final now = DateTime.now();
      final updatedEvent = event.copyWith(updatedAt: now);
      _cache[index] = updatedEvent;
      await _save();
    }
  }

  @override
  Future<Event?> findEventById(String eventId) async {
    await _init();
    try {
      return _cache.firstWhere((e) => e.id == eventId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await _init();
    final index = _cache.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      final now = DateTime.now();
      _cache[index] = _cache[index].copyWith(
        deletedAt: now,
        updatedAt: now,
      );
      await _save();
    }
  }

  @override
  Stream<List<Event>> streamEvents() {
    // We wrap the stream to ensure the current cache is emitted immediately
    // to every new listener, similar to a BehaviorSubject.
    final controller = StreamController<List<Event>>();

    void emit() {
      if (!controller.isClosed) {
        controller.add(_cache.where((e) => e.deletedAt == null).toList());
      }
    }

    // Start loading data
    _init().then((_) => emit());

    // Listen to the master broadcast stream for future updates
    final subscription = _controller.stream.listen((events) {
      if (!controller.isClosed) {
        controller.add(events);
      }
    });

    controller.onCancel = () => subscription.cancel();

    return controller.stream;
  }
}
