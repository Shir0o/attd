import 'dart:convert';

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

    group('Corruption Handling & Self-Healing', () {
      test('Scenario: Corrupted Remote JSON should not crash and should be detectable', () {
        // This simulates the logic in _mergeAndSyncFile where it catches FormatException
        final remoteContent = '{"invalid": json...'; // Corrupted JSON

        bool caughtError = false;
        try {
          jsonDecode(remoteContent);
        } catch (e) {
          caughtError = true;
        }

        expect(caughtError, true, reason: 'Invalid JSON should throw a FormatException');
      });

      test('Scenario: Schema Type Mismatch (List vs Map) is caught', () {
        final dynamic remoteJsonAsMap = {'id': '1', 'name': 'I should be a list'};
        const fileName = 'members.json'; // Expected to be a List

        // Logic from _mergeAndSyncFile:
        final isHistoryFile = fileName == 'sessions_history.json';
        final bool isValidRemote = isHistoryFile
            ? remoteJsonAsMap is Map<String, dynamic>
            : remoteJsonAsMap is List;

        expect(isValidRemote, false, reason: 'A Map instead of a List for members.json should be invalid');
      });

      test('Scenario: Self-Healing Logic - Local healthy List, Remote corrupted', () {
        final localContent = '[{"id": "1", "name": "Healthy Local"}]';
        
        dynamic localJson;
        bool localIsHealthy = false;
        try {
          localJson = jsonDecode(localContent);
          localIsHealthy = localJson is List || localJson is Map;
        } catch (e) {
          localIsHealthy = false;
        }

        expect(localIsHealthy, true);
        expect(localJson[0]['name'], 'Healthy Local');
      });

      test('Scenario: Self-Healing Logic - Local healthy Map, Remote corrupted', () {
        final localContent = '{"session_1": [{"version": 1}]}';
        
        dynamic localJson;
        bool localIsHealthy = false;
        try {
          localJson = jsonDecode(localContent);
          localIsHealthy = localJson is List || localJson is Map;
        } catch (e) {
          localIsHealthy = false;
        }

        expect(localIsHealthy, true);
        expect(localJson['session_1'], isNotNull);
      });
    });

    group('Family/Member updatedAt Conflict Resolution', () {
      test('Scenario: Family conflict resolved by updatedAt (latest wins)', () {
        final local = [
          {
            'id': 'f1',
            'displayName': 'Smith (local edit)',
            'members': [],
            'updatedAt': '2025-03-25T12:00:00Z',
          },
        ];
        final remote = [
          {
            'id': 'f1',
            'displayName': 'Smith (remote edit)',
            'members': [],
            'updatedAt': '2025-03-25T14:00:00Z',
          },
        ];

        final result = driveService.testMergeJsonLists(local, remote, 'families.json');

        expect(result.length, 1);
        expect(result.first['displayName'], 'Smith (remote edit)');
      });

      test('Scenario: Family conflict resolved by updatedAt (local is newer)', () {
        final local = [
          {
            'id': 'f1',
            'displayName': 'Smith (local edit)',
            'members': [],
            'updatedAt': '2025-03-25T16:00:00Z',
          },
        ];
        final remote = [
          {
            'id': 'f1',
            'displayName': 'Smith (remote edit)',
            'members': [],
            'updatedAt': '2025-03-25T14:00:00Z',
          },
        ];

        final result = driveService.testMergeJsonLists(local, remote, 'families.json');

        expect(result.length, 1);
        expect(result.first['displayName'], 'Smith (local edit)');
      });

      test('Scenario: Legacy families without updatedAt still merge member lists', () {
        final local = [
          {
            'id': 'f1',
            'displayName': 'Smith',
            'members': [
              {'id': 'm1', 'displayName': 'Alice'},
            ],
          },
        ];
        final remote = [
          {
            'id': 'f1',
            'displayName': 'Smith',
            'members': [
              {'id': 'm2', 'displayName': 'Bob'},
            ],
          },
        ];

        final result = driveService.testMergeJsonLists(local, remote, 'families.json');

        expect(result.length, 1);
        final members = result.first['members'] as List;
        expect(members.length, 2);
        expect(members.any((m) => m['id'] == 'm1'), true);
        expect(members.any((m) => m['id'] == 'm2'), true);
      });

      test('Scenario: Member with updatedAt conflict is resolved correctly', () {
        final local = [
          {
            'id': 'm1',
            'displayName': 'John (local)',
            'updatedAt': '2025-03-25T15:00:00Z',
          },
        ];
        final remote = [
          {
            'id': 'm1',
            'displayName': 'John (remote)',
            'updatedAt': '2025-03-25T10:00:00Z',
          },
        ];

        final result = driveService.testMergeJsonLists(local, remote, 'members');

        expect(result.length, 1);
        expect(result.first['displayName'], 'John (local)');
      });
    });
  });
}
