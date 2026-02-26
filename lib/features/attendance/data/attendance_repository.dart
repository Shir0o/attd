import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/family.dart';
import '../models/member.dart';

abstract class AttendanceRepository {
  Future<List<Family>> fetchFamilies();

  Future<void> saveFamilies(List<Family> families);

  Future<Family> addMember(String familyId, Member member);

  Future<Family> addFamily(String displayName);

  Future<void> refresh();
}

class LocalJsonAttendanceRepository extends AttendanceRepository {
  LocalJsonAttendanceRepository({this.storagePath});

  final String? storagePath;
  List<Family>? _cachedFamilies;

  @override
  Future<void> refresh() async {
    _cachedFamilies = null;
    await fetchFamilies();
  }

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
      await saveFamilies([]);
      return [];
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      await saveFamilies([]);
      return [];
    }

    final decoded = jsonDecode(content);
    if (decoded is! List) {
      _cachedFamilies = [];
      return [];
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
