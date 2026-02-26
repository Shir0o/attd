import 'dart:convert';
import 'dart:io';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalJsonAttendanceRepository Cache', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('attd-cache-test');
      dbPath = '${tempDir.path}/families.json';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('fetchFamilies uses cache on subsequent calls', () async {
      // Create initial families via pre-populating file
      await File(dbPath).create(recursive: true);
      final initialData = [
        Family(id: 'f1', displayName: 'Family 1', members: const []),
      ];
      await File(
        dbPath,
      ).writeAsString(jsonEncode(initialData.map((e) => e.toJson()).toList()));

      final repo = LocalJsonAttendanceRepository(storagePath: dbPath);

      // First call - loads from file
      final families1 = await repo.fetchFamilies();
      expect(families1.length, 1);
      expect(families1.first.displayName, 'Family 1');

      // Modify the file directly to see if the next call hits the cache
      await File(dbPath).writeAsString('[]');

      // Second call - should return cached data, not the empty list from file
      final families2 = await repo.fetchFamilies();
      expect(families2.length, 1);
      expect(families2.first.displayName, 'Family 1');
    });

    test('saveFamilies updates the cache', () async {
      final repo = LocalJsonAttendanceRepository(storagePath: dbPath);

      final newFamilies = [
        Family(id: 'f2', displayName: 'Family 2', members: const []),
      ];

      await repo.saveFamilies(newFamilies);

      // Modify the file directly
      await File(dbPath).writeAsString('[]');

      // fetchFamilies should return the saved (cached) data
      final families = await repo.fetchFamilies();
      expect(families.length, 1);
      expect(families.first.displayName, 'Family 2');
    });

    test(
      'fetchFamilies returns a copy of the list to prevent external mutation',
      () async {
        await File(dbPath).create(recursive: true);
        final initialData = [
          Family(id: 'f1', displayName: 'Family 1', members: const []),
        ];
        await File(dbPath).writeAsString(
          jsonEncode(initialData.map((e) => e.toJson()).toList()),
        );

        final repo = LocalJsonAttendanceRepository(storagePath: dbPath);

        final families1 = await repo.fetchFamilies();
        families1.clear(); // Mutate the returned list

        final families2 = await repo.fetchFamilies();
        expect(
          families2.length,
          1,
        ); // Should still have 1 element if cached list was copied
      },
    );
  });
}
