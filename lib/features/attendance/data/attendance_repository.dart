import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/family.dart';
import '../models/member.dart';

abstract class AttendanceRepository {
  Future<List<Family>> fetchFamilies();

  Future<void> saveFamilies(List<Family> families);

  Future<Family> addMember(String familyId, Member member);

  Future<Family> addFamily(String displayName);
}

class LocalJsonAttendanceRepository extends AttendanceRepository {
  LocalJsonAttendanceRepository({required this.path, List<Family>? seed})
    : _seed = seed ?? defaultFamilies;

  final String path;
  final List<Family> _seed;

  File get _file => File(path);

  @override
  Future<List<Family>> fetchFamilies() async {
    if (!await _file.exists()) {
      await saveFamilies(_seed);
      return _seed;
    }

    final content = await _file.readAsString();
    if (content.trim().isEmpty) {
      await saveFamilies(_seed);
      return _seed;
    }

    final decoded = jsonDecode(content);
    if (decoded is! List) return _seed;
    return decoded
        .map((entry) => Family.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveFamilies(List<Family> families) async {
    await _file.create(recursive: true);
    final payload = families.map((family) => family.toJson()).toList();
    await _file.writeAsString(jsonEncode(payload));
  }

  @override
  Future<Family> addMember(String familyId, Member member) async {
    final families = await fetchFamilies();
    final updated = families.map((family) {
      if (family.id != familyId) return family;
      return family.copyWith(members: [...family.members, member]);
    }).toList();
    await saveFamilies(updated);
    return updated.firstWhere((family) => family.id == familyId);
  }

  @override
  Future<Family> addFamily(String displayName) async {
    final family = Family(
      id: const Uuid().v4(),
      displayName: displayName,
      members: const [],
    );
    final families = await fetchFamilies();
    await saveFamilies([...families, family]);
    return family;
  }
}

class FirestoreAttendanceRepository extends AttendanceRepository {
  FirestoreAttendanceRepository({
    FirebaseFirestore? firestore,
    List<Family>? seed,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _seed = seed;

  final FirebaseFirestore _firestore;
  final List<Family>? _seed;

  CollectionReference<Map<String, dynamic>> get _familiesRef =>
      _firestore.collection('families');

  @override
  Future<List<Family>> fetchFamilies() async {
    final snapshot = await _familiesRef.get();

    if (snapshot.docs.isEmpty) {
      final families = _seed ?? defaultFamilies;
      await saveFamilies(families);
      return families;
    }

    return snapshot.docs.map((doc) => Family.fromJson(doc.data())).toList();
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
  Future<Family> addMember(String familyId, Member member) async {
    final docRef = _familiesRef.doc(familyId);

    // We use arrayUnion to atomically add the new member to the members list
    await docRef.update({
      'members': FieldValue.arrayUnion([member.toJson()]),
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
}

class SqliteAttendanceRepository extends AttendanceRepository {
  SqliteAttendanceRepository();

  @override
  Future<Family> addFamily(String displayName) {
    throw UnimplementedError('SQLite attendance storage not implemented yet.');
  }

  @override
  Future<Family> addMember(String familyId, Member member) {
    throw UnimplementedError('SQLite attendance storage not implemented yet.');
  }

  @override
  Future<List<Family>> fetchFamilies() {
    throw UnimplementedError('SQLite attendance storage not implemented yet.');
  }

  @override
  Future<void> saveFamilies(List<Family> families) {
    throw UnimplementedError('SQLite attendance storage not implemented yet.');
  }
}

const List<Family> defaultFamilies = [
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
