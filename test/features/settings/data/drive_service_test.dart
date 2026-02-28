import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:attendance_tracker/features/settings/data/drive_service.dart';

void main() {
  group('DriveService Merge Logic Scenarios', () {
    late DriveService driveService;

    setUp(() {
      // We don't need real dependencies for testing static merge logic
      driveService = DriveService(googleSignIn: GoogleSignIn());
    });

    test('Scenario: Independent changes should be merged (Union)', () {
      final local = [
        {'id': 'member_1', 'name': 'Member A', 'updatedAt': '2025-02-27T10:00:00Z'},
        {'id': 'member_2', 'name': 'Member B', 'updatedAt': '2025-02-27T10:00:00Z'},
      ];
      final remote = [
        {'id': 'member_1', 'name': 'Member A', 'updatedAt': '2025-02-27T10:00:00Z'},
        {'id': 'member_3', 'name': 'Member C', 'updatedAt': '2025-02-27T10:00:00Z'},
      ];

      final result = driveService.testMergeJsonLists(local, remote, 'members.json');

      expect(result.length, 3);
      expect(result.any((m) => m['id'] == 'member_1'), true);
      expect(result.any((m) => m['id'] == 'member_2'), true);
      expect(result.any((m) => m['id'] == 'member_3'), true);
    });

    test('Scenario: Conflict resolution favors the most recent change (UpdatedAt)', () {
      final local = [
        {'id': 'member_1', 'name': 'Member A (Local Edit)', 'updatedAt': '2025-02-27T11:00:00Z'},
      ];
      final remote = [
        {'id': 'member_1', 'name': 'Member A (Remote Edit)', 'updatedAt': '2025-02-27T12:00:00Z'},
      ];

      final result = driveService.testMergeJsonLists(local, remote, 'members.json');

      expect(result.length, 1);
      expect(result.first['name'], 'Member A (Remote Edit)');
    });

    test('Scenario: Session history merging combines all versions sorted by version number', () {
      final local = {
        'session_id_1': [
          {'version': 2, 'recordedAt': '2025-02-27T10:30:00Z'},
          {'version': 1, 'recordedAt': '2025-02-27T10:00:00Z'},
        ]
      };
      final remote = {
        'session_id_1': [
          {'version': 3, 'recordedAt': '2025-02-27T11:00:00Z'},
          {'version': 1, 'recordedAt': '2025-02-27T10:00:00Z'},
        ]
      };

      final result = driveService.testMergeHistoryMaps(local, remote);

      final history = result['session_id_1'] as List;
      expect(history.length, 3);
      expect(history[0]['version'], 3); // Sorted descending
      expect(history[1]['version'], 2);
      expect(history[2]['version'], 1);
    });

    test('Scenario: Edge Case - One side has empty data', () {
      final local = <Map<String, dynamic>>[];
      final remote = [
        {'id': 'member_1', 'name': 'Remote User', 'updatedAt': '2025-02-27T10:00:00Z'},
      ];

      final result = driveService.testMergeJsonLists(local, remote, 'members.json');

      expect(result.length, 1);
      expect(result.first['name'], 'Remote User');
    });
  });
}
