import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/family.dart';
import '../models/member.dart';

enum AttendanceStore { localJson, sqlite, firestore }

abstract class AttendanceRepository {
  AttendanceStore get store;

  Future<List<Family>> fetchFamilies();

  Future<void> saveFamilies(List<Family> families);

  Future<Family> addVisitor(String familyId, Member visitor);
}

class LocalJsonAttendanceRepository implements AttendanceRepository {
  LocalJsonAttendanceRepository({this.fileName = 'families.json', List<Family>? seed})
      : _seed = seed;

  final String fileName;
  final List<Family>? _seed;
  List<Family>? _memoryCache;

  @override
  AttendanceStore get store => AttendanceStore.localJson;

  Future<File> _resolveFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$fileName');
  }

  @override
  Future<List<Family>> fetchFamilies() async {
    if (_memoryCache != null) return _memoryCache!;

    final file = await _resolveFile();
    if (!await file.exists()) {
      final families = _seed ?? _defaultFamilies;
      await saveFamilies(families);
      _memoryCache = families;
      return families;
    }

    final content = await file.readAsString();
    final data = jsonDecode(content) as List<dynamic>;
    final families = data
        .map((family) => Family.fromJson(family as Map<String, dynamic>))
        .toList();
    _memoryCache = families;
    return families;
  }

  @override
  Future<void> saveFamilies(List<Family> families) async {
    final file = await _resolveFile();
    final serialized = jsonEncode(families.map((family) => family.toJson()).toList());
    await file.writeAsString(serialized, flush: true);
    _memoryCache = families;
  }

  @override
  Future<Family> addVisitor(String familyId, Member visitor) async {
    final families = await fetchFamilies();
    final updatedFamilies = families.map((family) {
      if (family.id != familyId) return family;
      final members = [...family.members, visitor];
      return family.copyWith(members: members);
    }).toList();
    await saveFamilies(updatedFamilies);
    return updatedFamilies.firstWhere((family) => family.id == familyId);
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

class SQLiteAttendanceRepository extends AttendanceRepository {
  SQLiteAttendanceRepository({AttendanceRepository? fallback})
      : _delegate = fallback ?? LocalJsonAttendanceRepository();

  final AttendanceRepository _delegate;

  @override
  AttendanceStore get store => AttendanceStore.sqlite;

  @override
  Future<Family> addVisitor(String familyId, Member visitor) {
    return _delegate.addVisitor(familyId, visitor);
  }

  @override
  Future<List<Family>> fetchFamilies() {
    return _delegate.fetchFamilies();
  }

  @override
  Future<void> saveFamilies(List<Family> families) {
    return _delegate.saveFamilies(families);
  }
}

class FirestoreAttendanceRepository extends AttendanceRepository {
  FirestoreAttendanceRepository({AttendanceRepository? fallback})
      : _delegate = fallback ?? LocalJsonAttendanceRepository();

  final AttendanceRepository _delegate;

  @override
  AttendanceStore get store => AttendanceStore.firestore;

  @override
  Future<Family> addVisitor(String familyId, Member visitor) {
    return _delegate.addVisitor(familyId, visitor);
  }

  @override
  Future<List<Family>> fetchFamilies() {
    return _delegate.fetchFamilies();
  }

  @override
  Future<void> saveFamilies(List<Family> families) {
    return _delegate.saveFamilies(families);
  }
}
