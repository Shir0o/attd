import '../domain/event.dart';

abstract class EventRepository {
  Future<void> createEvent(Event event);
  Future<void> updateEvent(Event event);
  Future<void> deleteEvent(String eventId);
  Future<Event?> findEventById(String eventId);
  Stream<List<Event>> streamEvents();
  Future<void> refresh();

  /// Permanently removes items that were marked as deleted before [threshold].
  Future<void> pruneSoftDeleted(DateTime threshold);
}
