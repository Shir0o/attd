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

    final directory = storagePath != null
        ? Directory(storagePath!)
        : await getApplicationDocumentsDirectory();

    _file = File('${directory.path}/events.json');
    return _file!;
  }

  Future<void> _init() async {
    if (_initialized) return;

    final file = await _storageFile;
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(content);
          _cache = jsonList.map((e) => Event.fromJson(e)).toList();
        }
      } catch (e) {
        print('Error reading events.json: $e');
        _cache = [];
      }
    } else {
      _cache = [];
    }

    _controller.add(_cache);
    _initialized = true;
  }

  Future<void> _save() async {
    final file = await _storageFile;
    final jsonList = _cache.map((e) => e.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
    _controller.add(_cache);
  }

  @override
  Future<void> createEvent(Event event) async {
    await _init();
    _cache.insert(0, event); // Add to top
    await _save();
  }

  @override
  Future<void> updateEvent(Event event) async {
    await _init();
    final index = _cache.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      _cache[index] = event;
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
    _init(); // Trigger init if not already
    return _controller.stream;
  }
}
