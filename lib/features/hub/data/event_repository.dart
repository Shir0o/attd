import '../domain/event.dart';

abstract class EventRepository {
  Future<void> createEvent(Event event);
  Future<void> updateEvent(Event event);
  Future<void> deleteEvent(String eventId);
  Stream<List<Event>> streamEvents();
}
