
import 'package:uuid/uuid.dart';

import '../models/family.dart';
import '../models/member.dart';


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/family.dart';
import '../models/member.dart';

abstract class AttendanceRepository {
  Future<List<Family>> fetchFamilies();

  Future<void> saveFamilies(List<Family> families);

  Future<Family> addVisitor(String familyId, Member visitor);

  Future<Family> addFamily(String displayName);
}

class FirestoreAttendanceRepository extends AttendanceRepository {
  FirestoreAttendanceRepository({
    FirebaseFirestore? firestore,
    List<Family>? seed,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _seed = seed;

  final FirebaseFirestore _firestore;
  final List<Family>? _seed;

  @override

  CollectionReference<Map<String, dynamic>> get _familiesRef =>
      _firestore.collection('families');

  @override
  Future<List<Family>> fetchFamilies() async {
    final snapshot = await _familiesRef.get();
    
    if (snapshot.docs.isEmpty) {
      final families = _seed ?? _defaultFamilies;
      await saveFamilies(families);
      return families;
    }

    return snapshot.docs
        .map((doc) => Family.fromJson(doc.data()))
        .toList();
  }

  @override
  Future<void> saveFamilies(List<Family> families) async {
    final batch = _firestore.batch();
    
    for (final family in families) {
      final docRef = _familiesRef.doc(family.id);
      batch.set(docRef, family.toJson());
    }
    
    await batch.commit();
  }

  @override
  Future<Family> addVisitor(String familyId, Member visitor) async {
    final docRef = _familiesRef.doc(familyId);
    
    // We use arrayUnion to atomically add the new member to the members list
    await docRef.update({
      'members': FieldValue.arrayUnion([visitor.toJson()]),
    });

    // Fetch the updated document to return the complete family object
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw StateError('Family not found: $familyId');
    }
    
    
    return Family.fromJson(snapshot.data()!);
  }

  @override
  Future<Family> addFamily(String displayName) async {
    final newFamily = Family(
      id: const Uuid().v4(),
      displayName: displayName,
      members: [],
    );
    
    await _familiesRef.doc(newFamily.id).set(newFamily.toJson());
    return newFamily;
  }

  List<Family> get _defaultFamilies => const [
        Family(
          id: 'family-1',
          displayName: 'Rivera Family',
          members: [
            Member(id: 'member-1', displayName: 'Alana Rivera'),
            Member(id: 'member-2', displayName: 'Mateo Rivera'),
            Member(id: 'member-3', displayName: 'Sofia Rivera'),
          ],
        ),
        Family(
          id: 'family-2',
          displayName: 'Nguyen Family',
          members: [
            Member(id: 'member-4', displayName: 'Minh Nguyen'),
            Member(id: 'member-5', displayName: 'Linh Nguyen'),
          ],
        ),
        Family(
          id: 'family-3',
          displayName: 'Patel Family',
          members: [
            Member(id: 'member-6', displayName: 'Aarav Patel'),
            Member(id: 'member-7', displayName: 'Anaya Patel'),
            Member(id: 'member-8', displayName: 'Rishi Patel'),
            Member(id: 'member-9', displayName: 'Priya Patel'),
          ],
        ),
      ];
}
