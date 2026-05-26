import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/logging/app_logger.dart';
import '../models/family.dart';
import '../models/member.dart';

final _log = AppLogger('AttendanceRepository');

abstract class AttendanceRepository {
  Future<List<Family>> fetchFamilies();

  Future<void> saveFamilies(List<Family> families);

  Future<Family> addMember(String familyId, Member member);

  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false});

  /// Moves [memberId] out of its current family and into [targetFamilyId].
  /// If the source family becomes empty as a result, it is left in place
  /// (soft-deleted families are pruned separately). The target family is
  /// returned with the member appended; its [Family.isAutoSingleton] is
  /// flipped to false once it holds more than one member.
  Future<Family> moveMemberToFamily(String memberId, String targetFamilyId) =>
      throw UnimplementedError();

  /// Removes [memberId] from its current family and places it in a fresh
  /// singleton family named after the member. Returns the new singleton.
  Future<Family> detachMember(String memberId) => throw UnimplementedError();

  Stream<List<Family>> streamFamilies();

  Future<void> refresh();

  /// Permanently removes items that were marked as deleted before [threshold].
  Future<void> pruneSoftDeleted(DateTime threshold);
}

class LocalJsonAttendanceRepository extends AttendanceRepository {
  LocalJsonAttendanceRepository({this.storagePath});

  final String? storagePath;
  List<Family>? _allFamilies;
  final _controller = StreamController<List<Family>>.broadcast();

  @override
  Future<void> refresh() async {
    _allFamilies = null;
    await fetchFamilies();
  }

  Future<File> get _file async {
    if (storagePath != null) return File(storagePath!);
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/families.json');
  }

  Future<List<Family>> _loadRawFamilies() async {
    if (_allFamilies != null) return List<Family>.from(_allFamilies!);
    
    final file = await _file;
    if (!await file.exists()) return [];

    final content = await file.readAsString();
    if (content.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(content);
      if (decoded is! List) return [];

      final families = decoded
          .map((entry) => Family.fromJson(entry as Map<String, dynamic>))
          .toList();
      _allFamilies = families;
      return List<Family>.from(families);
    } catch (e, st) {
      _log.error('Error loading raw families', e, st);
      return [];
    }
  }

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {
    final allFamilies = await _loadRawFamilies();
    bool changed = false;

    final prunedFamilies = <Family>[];
    for (final family in allFamilies) {
      if (family.deletedAt != null && family.deletedAt!.isBefore(threshold)) {
        changed = true;
        continue;
      }

      final prunedMembers = family.members.where((m) {
        if (m.deletedAt != null && m.deletedAt!.isBefore(threshold)) {
          changed = true;
          return false;
        }
        return true;
      }).toList();

      if (prunedMembers.length != family.members.length) {
        prunedFamilies.add(family.copyWith(members: prunedMembers));
        changed = true;
      } else {
        prunedFamilies.add(family);
      }
    }

    if (changed) {
      await saveFamilies(prunedFamilies);
    }
  }

  @override
  Future<List<Family>> fetchFamilies() async {
    final all = await _loadRawFamilies();
    final visible = all
        .where((f) => f.deletedAt == null)
        .map((f) => f.copyWith(
          members: f.members.where((m) => m.deletedAt == null).toList(),
        ))
        .toList();

    return List<Family>.from(visible);
  }

  @override
  Future<void> saveFamilies(List<Family> families) async {
    _allFamilies = families;
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
    } catch (e, st) {
      _log.error('Error during attendance save', e, st);
      // Restore from backup if possible
      if (await backupFile.exists() && !await file.exists()) {
        await backupFile.copy(file.path);
      }
    }
    
    _controller.add(await fetchFamilies());
  }

  @override
  Future<Family> addMember(String familyId, Member member) async {
    final families = await _loadRawFamilies();
    final now = DateTime.now();
    final memberWithTimestamp = member.copyWith(updatedAt: now);
    final updated = families.map((family) {
      if (family.id != familyId) return family;
      final newMembers = [...family.members, memberWithTimestamp];
      final liveCount = newMembers.where((m) => m.deletedAt == null).length;
      return family.copyWith(
        members: newMembers,
        updatedAt: now,
        // Adding a second live member promotes the family out of singleton.
        isAutoSingleton: family.isAutoSingleton && liveCount <= 1,
      );
    }).toList();
    await saveFamilies(updated);

    // We need to return the family as visible to the UI (without deleted members)
    final savedFamily = updated.firstWhere((family) => family.id == familyId);
    return savedFamily.copyWith(
      members: savedFamily.members.where((m) => m.deletedAt == null).toList(),
    );
  }

  @override
  Future<Family> addFamily(
    String displayName, {
    bool isAutoSingleton = false,
  }) async {
    final now = DateTime.now();
    final family = Family(
      id: const Uuid().v4(),
      displayName: displayName,
      members: const [],
      updatedAt: now,
      isAutoSingleton: isAutoSingleton,
    );
    final families = await _loadRawFamilies();
    await saveFamilies([...families, family]);
    return family;
  }

  @override
  Future<Family> moveMemberToFamily(
    String memberId,
    String targetFamilyId,
  ) async {
    final families = await _loadRawFamilies();
    final now = DateTime.now();
    Member? moving;
    final stripped = families.map((family) {
      if (!family.members.any((m) => m.id == memberId)) return family;
      final remaining = <Member>[];
      for (final m in family.members) {
        if (m.id == memberId) {
          moving = m;
        } else {
          remaining.add(m);
        }
      }
      return family.copyWith(members: remaining, updatedAt: now);
    }).where((f) => !f.isAutoSingleton || f.members.isNotEmpty).toList();
    if (moving == null) {
      throw StateError('Member $memberId not found in any family');
    }
    final updated = stripped.map((family) {
      if (family.id != targetFamilyId) return family;
      final newMembers = [...family.members, moving!.copyWith(updatedAt: now)];
      final liveCount = newMembers.where((m) => m.deletedAt == null).length;
      return family.copyWith(
        members: newMembers,
        updatedAt: now,
        isAutoSingleton: family.isAutoSingleton && liveCount <= 1,
      );
    }).toList();
    if (!updated.any((f) => f.id == targetFamilyId)) {
      throw StateError('Target family $targetFamilyId not found');
    }
    await saveFamilies(updated);
    final saved = updated.firstWhere((f) => f.id == targetFamilyId);
    return saved.copyWith(
      members: saved.members.where((m) => m.deletedAt == null).toList(),
    );
  }

  @override
  Future<Family> detachMember(String memberId) async {
    final families = await _loadRawFamilies();
    final now = DateTime.now();
    Member? moving;
    final stripped = families.map((family) {
      if (!family.members.any((m) => m.id == memberId)) return family;
      final remaining = <Member>[];
      for (final m in family.members) {
        if (m.id == memberId) {
          moving = m;
        } else {
          remaining.add(m);
        }
      }
      return family.copyWith(members: remaining, updatedAt: now);
    }).where((f) => !f.isAutoSingleton || f.members.isNotEmpty).toList();
    if (moving == null) {
      throw StateError('Member $memberId not found in any family');
    }
    final singleton = Family(
      id: const Uuid().v4(),
      displayName: moving!.displayName,
      members: [moving!.copyWith(updatedAt: now)],
      updatedAt: now,
      isAutoSingleton: true,
    );
    await saveFamilies([...stripped, singleton]);
    return singleton;
  }

  @override
  Stream<List<Family>> streamFamilies() {
    final controller = StreamController<List<Family>>();

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
