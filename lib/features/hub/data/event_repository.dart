import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/event.dart';

abstract class EventRepository {
  Future<void> createEvent(Event event);
  Future<void> updateEvent(Event event);
  Future<void> deleteEvent(String eventId);
  Stream<List<Event>> streamEvents();
}

class FirestoreEventRepository implements EventRepository {
  final FirebaseFirestore _firestore;

  FirestoreEventRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection('events');

  @override
  Future<void> createEvent(Event event) async {
    await _eventsRef.doc(event.id).set(event.toJson());
  }

  @override
  Future<void> updateEvent(Event event) async {
    await _eventsRef.doc(event.id).update(event.toJson());
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await _eventsRef.doc(eventId).delete();
  }

  @override
  Stream<List<Event>> streamEvents() {
    return _eventsRef.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => Event.fromJson(doc.data())).toList();
    });
  }
}
