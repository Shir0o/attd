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

  @override
  Future<void> refresh() async {
    _initialized = false;
    await _init();
  }

  Future<void> _init() async {
    if (_initialized) {
      _controller.add(_cache);
      return;
    }

    final file = await _storageFile;
    final backupFile = File('${file.path}.bak');

    if (!await file.exists()) {
      if (await backupFile.exists()) {
        await backupFile.copy(file.path);
      } else {
        _cache = [];
        _controller.add(_cache);
        _initialized = true;
        return;
      }
    }

    try {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(content);
        _cache = jsonList.map((e) => Event.fromJson(e)).toList();
      } else {
        _cache = [];
      }
    } catch (e) {
      print('Events storage corrupted, attempting recovery: $e');
      try {
        if (await backupFile.exists()) {
          final backupContent = await backupFile.readAsString();
          final List<dynamic> jsonList = jsonDecode(backupContent);
          print('Successfully recovered events from .bak file');
          _cache = jsonList.map((e) => Event.fromJson(e)).toList();
        } else {
          _cache = [];
        }
      } catch (backupError) {
        print('Events backup recovery failed: $backupError');
        _cache = [];
      }
    }

    _controller.add(_cache);
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
    
    _controller.add(_cache);
  }

  @override
  Future<void> createEvent(Event event) async {
    await _init();
    final now = DateTime.now();
    final newEvent = Event(
      id: event.id,
      title: event.title,
      time: event.time,
      frequency: event.frequency,
      oneTimeDate: event.oneTimeDate,
      repeatingDays: event.repeatingDays,
      memberIds: event.memberIds,
      createdAt: event.createdAt,
      updatedAt: now,
    );
    _cache.insert(0, newEvent); // Add to top
    await _save();
  }

  @override
  Future<void> updateEvent(Event event) async {
    await _init();
    final index = _cache.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      final now = DateTime.now();
      final updatedEvent = Event(
        id: event.id,
        title: event.title,
        time: event.time,
        frequency: event.frequency,
        oneTimeDate: event.oneTimeDate,
        repeatingDays: event.repeatingDays,
        memberIds: event.memberIds,
        createdAt: event.createdAt,
        updatedAt: now,
      );
      _cache[index] = updatedEvent;
      await _save();
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await _init();
    _cache.removeWhere((e) => e.id == eventId);
    await _save();
  }

  @override
  Stream<List<Event>> streamEvents() {
    // We wrap the stream to ensure the current cache is emitted immediately
    // to every new listener, similar to a BehaviorSubject.
    final controller = StreamController<List<Event>>();

    void emit() {
      if (!controller.isClosed) {
        controller.add(_cache);
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
