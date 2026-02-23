import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
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
  LocalJsonAttendanceRepository({this.storagePath, List<Family>? seed})
    : _seed = seed ?? defaultFamilies;

  final String? storagePath;
  final List<Family> _seed;
  List<Family>? _cachedFamilies;

  Future<File> get _file async {
    if (storagePath != null) return File(storagePath!);
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/families.json');
  }

  @override
  Future<List<Family>> fetchFamilies() async {
    if (_cachedFamilies != null) {
      return List<Family>.from(_cachedFamilies!);
    }

    final file = await _file;
    if (!await file.exists()) {
      await saveFamilies(_seed);
      return List<Family>.from(_seed);
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      await saveFamilies(_seed);
      return List<Family>.from(_seed);
    }

    final decoded = jsonDecode(content);
    if (decoded is! List) {
      _cachedFamilies = List<Family>.from(_seed);
      return List<Family>.from(_seed);
    }

    final families = decoded
        .map((entry) => Family.fromJson(entry as Map<String, dynamic>))
        .toList();

    _cachedFamilies = families;
    return List<Family>.from(families);
  }

  @override
  Future<void> saveFamilies(List<Family> families) async {
    _cachedFamilies = List<Family>.from(families);
    final file = await _file;
    await file.create(recursive: true);
    final payload = families.map((family) => family.toJson()).toList();
    await file.writeAsString(jsonEncode(payload));
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
