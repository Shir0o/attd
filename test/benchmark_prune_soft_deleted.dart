import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';

void main() {
  test('Benchmark pruneSoftDeleted in-memory filtering performance', () async {
    final tempDir = Directory.systemTemp.createTempSync('benchmark_prune');
    final dbPath = '${tempDir.path}/families.json';

    try {
      final now = DateTime.now();
      final threshold = now.subtract(const Duration(days: 30));
      final oldDate = now.subtract(const Duration(days: 60));
      final recentDate = now.subtract(const Duration(days: 5));

      // Generate 1000 families, each with 5 members (~5000 total members)
      final families = <Family>[];
      for (var f = 0; f < 1000; f++) {
        final familyDeleted = (f % 20 == 0);
        final familyDeletedAt = familyDeleted ? oldDate : null;

        final members = <Member>[];
        for (var m = 0; m < 5; m++) {
          final memberDeleted = !familyDeleted && (m == 0 && f % 20 == 1);
          members.add(Member(
            id: 'fam_${f}_mem_$m',
            displayName: 'Member $f-$m',
            deletedAt:
                memberDeleted ? oldDate : (f % 10 == 0 ? recentDate : null),
          ));
        }

        families.add(Family(
          id: 'fam_$f',
          displayName: 'Family $f',
          members: members,
          deletedAt: familyDeletedAt,
          updatedAt: now,
        ));
      }

      final repo = LocalJsonAttendanceRepository(storagePath: dbPath);

      // Measure 1: When pruneSoftDeleted runs on dataset where no changes are needed (e.g. after initial prune)
      await repo.saveFamilies(families);
      await repo.pruneSoftDeleted(threshold); // first pass prunes stale items

      const iterationsNoChange = 1000;
      final swNoChange = Stopwatch()..start();
      for (var i = 0; i < iterationsNoChange; i++) {
        await repo.pruneSoftDeleted(threshold);
      }
      swNoChange.stop();

      print(
          'pruneSoftDeleted (No changes needed) x$iterationsNoChange: ${swNoChange.elapsedMilliseconds} ms');
      print(
          '  Average per call: ${(swNoChange.elapsedMicroseconds / iterationsNoChange).toStringAsFixed(2)} us');
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });
}
