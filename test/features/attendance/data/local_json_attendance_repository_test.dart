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
          labels: const LabelAssignments(manualLabels: {'follow-up'}),
          members: [
            Member(
              id: 'm1',
              displayName: 'Avery',
              canonicalName: 'Avery A',
              mergedIntoMemberId: 'm2',
              labels: LabelAssignments(autoLabels: {'follow-up'}),
            ),
            Member(id: 'm2', displayName: 'Avery A'),
          ],
        ),
      ];

      await repo.saveFamilies(families);
      final loaded = await repo.fetchFamilies();

      expect(loaded.single.labels.manualLabels, contains('follow-up'));
      expect(loaded.single.members.first.mergedIntoMemberId, 'm2');
      expect(
        loaded.single.members.first.labels.autoLabels,
        contains('follow-up'),
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

    test('pruneSoftDeleted is a no-op when nothing is stale', () async {
      final repo = LocalJsonAttendanceRepository(storagePath: dbPath);
      final now = DateTime.now();
      await repo.saveFamilies([
        Family(
          id: 'keep',
          displayName: 'Keep',
          updatedAt: now,
          members: [Member(id: 'm1', displayName: 'Alice')],
        ),
      ]);

      // No deletions -> repository should not rewrite the file.
      final beforeContent = await File(dbPath).readAsString();
      await repo.pruneSoftDeleted(now);
      final afterContent = await File(dbPath).readAsString();

      expect(afterContent, beforeContent);
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

    test('addFamily honors isAutoSingleton flag', () async {
      final repo = LocalJsonAttendanceRepository(storagePath: dbPath);
      final auto = await repo.addFamily('Alice', isAutoSingleton: true);
      expect(auto.isAutoSingleton, isTrue);
      final real = await repo.addFamily('The Smiths');
      expect(real.isAutoSingleton, isFalse);
    });

    test('addMember on singleton flips isAutoSingleton off at 2 live members',
        () async {
      final repo = LocalJsonAttendanceRepository(storagePath: dbPath);
      final solo = await repo.addFamily('Alice', isAutoSingleton: true);
      await repo.addMember(
        solo.id,
        Member(id: 'm1', displayName: 'Alice'),
      );
      var families = await repo.fetchFamilies();
      expect(families.single.isAutoSingleton, isTrue);
      await repo.addMember(
        solo.id,
        Member(id: 'm2', displayName: 'Bob'),
      );
      families = await repo.fetchFamilies();
      expect(families.single.isAutoSingleton, isFalse);
    });

    test('fetchFamilies recovers from healthy backup file when main file is corrupted', () async {
      final mainFile = File(dbPath);
      final backupFile = File('$dbPath.bak');

      // Create a valid backup
      final now = DateTime.now();
      final families = [
        Family(
          id: 'fam-1',
          displayName: 'Recovered Family',
          members: const [],
          updatedAt: now,
        )
      ];
      await backupFile.writeAsString(jsonEncode(families.map((e) => e.toJson()).toList()));

      // Corrupt the main file
      await mainFile.writeAsString('{corrupted json');

      final repo = LocalJsonAttendanceRepository(storagePath: dbPath);
      final loaded = await repo.fetchFamilies();

      expect(loaded.length, 1);
      expect(loaded.first.displayName, 'Recovered Family');

      // Verify main file has been healed
      expect(mainFile.existsSync(), isTrue);
      expect(jsonDecode(mainFile.readAsStringSync()), isList);
    });

    test('fetchFamilies recovers from healthy backup file when main file is missing', () async {
      final mainFile = File(dbPath);
      final backupFile = File('$dbPath.bak');

      if (mainFile.existsSync()) {
        mainFile.deleteSync();
      }

      // Create a valid backup
      final now = DateTime.now();
      final families = [
        Family(
          id: 'fam-2',
          displayName: 'Recovered Family 2',
          members: const [],
          updatedAt: now,
        )
      ];
      await backupFile.writeAsString(jsonEncode(families.map((e) => e.toJson()).toList()));

      final repo = LocalJsonAttendanceRepository(storagePath: dbPath);
      final loaded = await repo.fetchFamilies();

      expect(loaded.length, 1);
      expect(loaded.first.displayName, 'Recovered Family 2');

      // Verify main file has been restored
      expect(mainFile.existsSync(), isTrue);
    });

    test('fetchAllFamilies works correctly', () async {
      final repo = LocalJsonAttendanceRepository(storagePath: dbPath);
      final now = DateTime.now();
      final families = [
        Family(
          id: 'fam-x',
          displayName: 'Test Family',
          members: const [],
          updatedAt: now,
        )
      ];
      await repo.saveFamilies(families);
      final fetched = await repo.fetchAllFamilies();
      expect(fetched.length, 1);
      expect(fetched.first.displayName, 'Test Family');
    });

    test('save error restores from backup', () async {
      final subDir = Directory('${tempDir.path}/restore_test');
      await subDir.create(recursive: true);
      final repo = LocalJsonAttendanceRepository(storagePath: '${subDir.path}/families.json');
      
      final now = DateTime.now();
      final families = [
        Family(
          id: 'fam-1',
          displayName: 'Initial Family',
          members: const [],
          updatedAt: now,
        )
      ];
      
      await repo.saveFamilies(families);
      await repo.saveFamilies(families); // Second call creates the backup

      final backupFile = File('${subDir.path}/families.json.bak');
      expect(backupFile.existsSync(), isTrue);

      final mainFile = File('${subDir.path}/families.json');
      if (mainFile.existsSync()) {
        mainFile.deleteSync();
      }

      final tempDirVar = Directory('${mainFile.path}.tmp');
      await tempDirVar.create(recursive: true);

      await repo.saveFamilies(families);

      expect(mainFile.existsSync(), isTrue);
      // Clean up the directory created at tmp path so it doesn't block other tests
      await tempDirVar.delete(recursive: true);
    });
  });
}
