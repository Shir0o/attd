import 'dart:convert';
import 'dart:io';

import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/label_assignments.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalJsonAttendanceRepository', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('attd-families');
      dbPath = '${tempDir.path}/families.json';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists merge markers and labels', () async {
      final repo = LocalJsonAttendanceRepository(storagePath: dbPath);
      final families = [
        Family(
          id: 'f1',
          displayName: 'Alpha',
          labels: const LabelAssignments(manualLabels: {watchlistLabel}),
          members: const [
            Member(
              id: 'm1',
              displayName: 'Avery',
              canonicalName: 'Avery A',
              mergedIntoMemberId: 'm2',
              labels: LabelAssignments(autoLabels: {watchlistLabel}),
            ),
            Member(id: 'm2', displayName: 'Avery A'),
          ],
        ),
      ];

      await repo.saveFamilies(families);
      final loaded = await repo.fetchFamilies();

      expect(loaded.single.labels.manualLabels, contains(watchlistLabel));
      expect(loaded.single.members.first.mergedIntoMemberId, 'm2');
      expect(
        loaded.single.members.first.labels.autoLabels,
        contains(watchlistLabel),
      );
    });

    test('is backward compatible with legacy files', () async {
      final legacyPayload = [
        {
          'id': 'legacy',
          'displayName': 'Legacy Family',
          'members': [
            {'id': 'm1', 'displayName': 'Legacy Member'},
          ],
        },
      ];
      await File(dbPath).create(recursive: true);
      await File(dbPath).writeAsString(jsonEncode(legacyPayload));

      final repo = LocalJsonAttendanceRepository(storagePath: dbPath);
      final loaded = await repo.fetchFamilies();

      expect(loaded.single.canonicalName, 'Legacy Family');
      expect(loaded.single.members.single.canonicalName, 'Legacy Member');
      expect(loaded.single.labels.all, isEmpty);
    });
  });
}
