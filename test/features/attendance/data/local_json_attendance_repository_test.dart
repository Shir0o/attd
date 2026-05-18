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
          members: [
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

    test('fetchFamilies hides deleted families and members', () async {
      final now = DateTime(2026, 5, 17);
      final repo = LocalJsonAttendanceRepository(storagePath: dbPath);
      await repo.saveFamilies([
        Family(
          id: 'visible',
          displayName: 'Visible',
          updatedAt: now,
          members: [
            Member(id: 'active', displayName: 'Active', updatedAt: now),
            Member(
              id: 'deleted-member',
              displayName: 'Deleted Member',
              updatedAt: now,
              deletedAt: now,
            ),
          ],
        ),
        Family(
          id: 'deleted-family',
          displayName: 'Deleted Family',
          members: const [],
          updatedAt: now,
          deletedAt: now,
        ),
      ]);

      final loaded = await repo.fetchFamilies();

      expect(loaded.map((family) => family.id), ['visible']);
      expect(loaded.single.members.map((member) => member.id), ['active']);
    });

    test('addFamily and addMember persist and emit visible families', () async {
      final repo = LocalJsonAttendanceRepository(storagePath: dbPath);
      final emissions = <List<Family>>[];
      final subscription = repo.streamFamilies().listen(emissions.add);

      final family = await repo.addFamily('  New Family  ');
      final updated = await repo.addMember(
        family.id,
        Member(id: 'm1', displayName: '  New Member  '),
      );

      await pumpEventQueue();
      await subscription.cancel();

      expect(family.displayName, 'New Family');
      expect(updated.members.single.displayName, 'New Member');
      expect((await repo.fetchFamilies()).single.members.single.id, 'm1');
      expect(emissions, isNotEmpty);
      expect(emissions.last.single.members.single.id, 'm1');
    });

    test('pruneSoftDeleted removes stale deleted families and members',
        () async {
      final now = DateTime(2026, 5, 17);
      final repo = LocalJsonAttendanceRepository(storagePath: dbPath);
      await repo.saveFamilies([
        Family(
          id: 'keep',
          displayName: 'Keep',
          updatedAt: now,
          members: [
            Member(
              id: 'old-member',
              displayName: 'Old Member',
              updatedAt: now,
              deletedAt: now.subtract(const Duration(days: 30)),
            ),
            Member(
              id: 'recent-member',
              displayName: 'Recent Member',
              updatedAt: now,
              deletedAt: now.subtract(const Duration(days: 1)),
            ),
          ],
        ),
        Family(
          id: 'old-family',
          displayName: 'Old Family',
          members: const [],
          updatedAt: now,
          deletedAt: now.subtract(const Duration(days: 30)),
        ),
      ]);

      await repo.pruneSoftDeleted(now.subtract(const Duration(days: 7)));

      final raw = jsonDecode(await File(dbPath).readAsString()) as List;
      expect(raw.map((entry) => entry['id']), ['keep']);
      final members = raw.single['members'] as List;
      expect(members.map((entry) => entry['id']), ['recent-member']);
    });

    test('invalid or non-list files load as empty', () async {
      await File(dbPath).create(recursive: true);
      await File(dbPath).writeAsString('{"unexpected": true}');

      final repo = LocalJsonAttendanceRepository(storagePath: dbPath);
      expect(await repo.fetchFamilies(), isEmpty);

      await File(dbPath).writeAsString('{not json');
      await repo.refresh();

      expect(await repo.fetchFamilies(), isEmpty);
    });
  });
}
