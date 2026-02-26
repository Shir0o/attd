import 'dart:convert';
import '../domain/event.dart';
import '../../attendance/models/family.dart';
import '../../attendance/data/attendance_repository.dart';
import '../data/event_repository.dart';

class SetupBundle {
  final List<Event> events;
  final List<Family> families;

  SetupBundle({required this.events, required this.families});

  Map<String, dynamic> toJson() {
    return {
      'version': 1,
      'events': events.map((e) => e.toJson()).toList(),
      'families': families.map((f) => f.toJson()).toList(),
    };
  }

  factory SetupBundle.fromJson(Map<String, dynamic> json) {
    return SetupBundle(
      events: (json['events'] as List).map((e) => Event.fromJson(e)).toList(),
      families: (json['families'] as List).map((f) => Family.fromJson(f)).toList(),
    );
  }
}

class SetupService {
  final AttendanceRepository attendanceRepository;
  final EventRepository eventRepository;

  SetupService({
    required this.attendanceRepository,
    required this.eventRepository,
  });

  Future<String> createBundle(List<String> selectedEventIds) async {
    final allEvents = await eventRepository.streamEvents().first;
    final selectedEvents = allEvents.where((e) => selectedEventIds.contains(e.id)).toList();
    final families = await attendanceRepository.fetchFamilies();

    final bundle = SetupBundle(events: selectedEvents, families: families);
    return jsonEncode(bundle.toJson());
  }

  Future<void> importBundle(String bundleJson) async {
    final data = jsonDecode(bundleJson);
    final bundle = SetupBundle.fromJson(data);

    // Merge logic: For simplicity, we'll add missing events and families
    final currentFamilies = await attendanceRepository.fetchFamilies();
    final existingFamilyIds = currentFamilies.map((f) => f.id).toSet();
    
    final newFamilies = [...currentFamilies];
    for (final f in bundle.families) {
      if (!existingFamilyIds.contains(f.id)) {
        newFamilies.add(f);
      }
    }
    await attendanceRepository.saveFamilies(newFamilies);

    final currentEvents = await eventRepository.streamEvents().first;
    final existingEventTitles = currentEvents.map((e) => e.title).toSet();

    for (final event in bundle.events) {
      if (!existingEventTitles.contains(event.title)) {
        await eventRepository.createEvent(event);
      }
    }
  }
}
