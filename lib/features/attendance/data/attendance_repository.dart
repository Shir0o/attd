import 'dart:async';
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

  Stream<List<Family>> streamFamilies();

  Future<void> refresh();
}

class LocalJsonAttendanceRepository extends AttendanceRepository {
  LocalJsonAttendanceRepository({this.storagePath});

  final String? storagePath;
  List<Family>? _cachedFamilies;
  final _controller = StreamController<List<Family>>.broadcast();

  @override
  Future<void> refresh() async {
    _cachedFamilies = null;
    final families = await fetchFamilies();
    _controller.add(families);
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
    final backupFile = File('${file.path}.bak');

    if (!await file.exists()) {
      if (await backupFile.exists()) {
        await backupFile.copy(file.path);
      } else {
        await saveFamilies([]);
        return [];
      }
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      await saveFamilies([]);
      return [];
    }

    try {
      final decoded = jsonDecode(content);
      if (decoded is! List) {
        _cachedFamilies = [];
        return [];
      }

      final families = decoded
          .map((entry) => Family.fromJson(entry as Map<String, dynamic>))
          .where((f) => f.deletedAt == null)
          .map((f) => f.copyWith(
            members: f.members.where((m) => m.deletedAt == null).toList(),
          ))
          .toList();

      _cachedFamilies = families;
      return List<Family>.from(families);
    } catch (e) {
      print('Attendance storage corrupted, attempting recovery: $e');
      try {
        if (await backupFile.exists()) {
          final backupContent = await backupFile.readAsString();
          final decoded = jsonDecode(backupContent);
          if (decoded is List) {
            print('Successfully recovered attendance from .bak file');
            return decoded
                .map((entry) => Family.fromJson(entry as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (backupError) {
        print('Attendance backup recovery failed: $backupError');
      }
      _cachedFamilies = [];
      return [];
    }
  }

  @override
  Future<void> saveFamilies(List<Family> families) async {
    _cachedFamilies = families
        .where((f) => f.deletedAt == null)
        .map((f) => f.copyWith(
          members: f.members.where((m) => m.deletedAt == null).toList(),
        ))
        .toList();
    final file = await _file;
    final tempFile = File('${file.path}.tmp');
    final backupFile = File('${file.path}.bak');

    try {
      final payload = families.map((family) => family.toJson()).toList();
      final content = jsonEncode(payload);

      // 1. Write to temp file
      await tempFile.writeAsString(content);

      // 2. Rotate current to backup
      if (await file.exists()) {
        await file.rename(backupFile.path);
      }

      // 3. Move temp to current (Atomic rename)
      await tempFile.rename(file.path);
    } catch (e) {
      print('Error during attendance save: $e');
      // Restore from backup if possible
      if (await backupFile.exists() && !await file.exists()) {
        await backupFile.copy(file.path);
      }
    }
    
    _controller.add(List<Family>.from(_cachedFamilies!));
  }

  @override
  Future<Family> addMember(String familyId, Member member) async {
    final families = await fetchFamilies();
    final now = DateTime.now();
    final memberWithTimestamp = member.copyWith(updatedAt: now);
    final updated = families.map((family) {
      if (family.id != familyId) return family;
      return family.copyWith(
        members: [...family.members, memberWithTimestamp],
        updatedAt: now,
      );
    }).toList();
    await saveFamilies(updated);
    return updated.firstWhere((family) => family.id == familyId);
  }

  @override
  Future<Family> addFamily(String displayName) async {
    final now = DateTime.now();
    final family = Family(
      id: const Uuid().v4(),
      displayName: displayName,
      members: const [],
      updatedAt: now,
    );
    final families = await fetchFamilies();
    await saveFamilies([...families, family]);
    return family;
  }

  @override
  Stream<List<Family>> streamFamilies() {
    final controller = StreamController<List<Family>>();

    void emit() {
      if (!controller.isClosed && _cachedFamilies != null) {
        controller.add(List<Family>.from(_cachedFamilies!));
      }
    }

    fetchFamilies().then((families) {
      if (!controller.isClosed) {
        controller.add(families);
      }
    });

    final subscription = _controller.stream.listen((families) {
      if (!controller.isClosed) {
        controller.add(families);
      }
    });

    controller.onCancel = () => subscription.cancel();

    return controller.stream;
  }
}
