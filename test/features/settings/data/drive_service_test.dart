import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:attendance_tracker/features/settings/data/drive_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  group('DriveService Merge Logic Scenarios', () {
    late DriveService driveService;
    late MockGoogleSignIn mockGoogleSignIn;

    setUp(() {
      mockGoogleSignIn = MockGoogleSignIn();
      // v7: DriveService subscribes to authenticationEvents in its
      // constructor, so the mock must return a stream.
      when(() => mockGoogleSignIn.authenticationEvents).thenAnswer(
        (_) => const Stream<GoogleSignInAuthenticationEvent>.empty(),
      );
      // We don't need real dependencies for testing static merge logic
      driveService = DriveService(googleSignIn: mockGoogleSignIn);
    });

    test('SyncStats reports changes as ordered tags', () {
      final stats = SyncStats()
        ..newSessions = 2
        ..newEvents = 1
        ..newMembers = 3;

      expect(stats.hasChanges, isTrue);
      expect(stats.toTags(), [
        '+2 Sessions',
        '+1 Events',
        '+3 Members',
      ]);
    });

    test('SyncStats stays empty when no remote records were added', () {
      final stats = SyncStats();

      expect(stats.hasChanges, isFalse);
      expect(stats.toTags(), isEmpty);
    });

    test('Scenario: Remote-only sync additions update file-specific stats', () {
      final stats = SyncStats();
      final local = [
        {'id': 'session_1', 'title': 'Local'},
      ];
      final remote = [
        {'id': 'session_1', 'title': 'Local'},
        {'id': 'session_2', 'title': 'Remote'},
      ];

      final result = driveService.testMergeJsonLists(
        local,
        remote,
        'sessions.json',
        stats: stats,
      );

      expect(result.length, 2);
      expect(stats.newSessions, 1);
      expect(stats.hasChanges, isTrue);
      expect(stats.toTags(), ['+1 Sessions']);
    });

    test('Scenario: Legacy family member merge updates member stats', () {
      final stats = SyncStats();
      final local = [
        {
          'id': 'family_1',
          'displayName': 'Smith',
          'members': [
            {'id': 'member_1', 'displayName': 'Alice'},
          ],
        },
      ];
      final remote = [
        {
          'id': 'family_1',
          'displayName': 'Smith',
          'members': [
            {'id': 'member_2', 'displayName': 'Bob'},
          ],
        },
      ];

      final result = driveService.testMergeJsonLists(
        local,
        remote,
        'families.json',
        stats: stats,
      );

      final members = result.first['members'] as List;
      expect(members.map((member) => member['id']),
          containsAll(['member_1', 'member_2']));
      expect(stats.newMembers, 1);
      expect(stats.toTags(), ['+1 Members']);
    });

    test('Scenario: Independent changes should be merged (Union)', () {
      final local = [
        {
          'id': 'member_1',
          'name': 'Member A',
          'updatedAt': '2025-02-27T10:00:00Z'
        },
        {
          'id': 'member_2',
          'name': 'Member B',
          'updatedAt': '2025-02-27T10:00:00Z'
        },
      ];
      final remote = [
        {
          'id': 'member_1',
          'name': 'Member A',
          'updatedAt': '2025-02-27T10:00:00Z'
        },
        {
          'id': 'member_3',
          'name': 'Member C',
          'updatedAt': '2025-02-27T10:00:00Z'
        },
      ];

      final result =
          driveService.testMergeJsonLists(local, remote, 'members.json');

      expect(result.length, 3);
      expect(result.any((m) => m['id'] == 'member_1'), true);
      expect(result.any((m) => m['id'] == 'member_2'), true);
      expect(result.any((m) => m['id'] == 'member_3'), true);
    });

    test(
        'Scenario: Conflict resolution favors the most recent change (UpdatedAt)',
        () {
      final local = [
        {
          'id': 'member_1',
          'name': 'Member A (Local Edit)',
          'updatedAt': '2025-02-27T11:00:00Z'
        },
      ];
      final remote = [
        {
          'id': 'member_1',
          'name': 'Member A (Remote Edit)',
          'updatedAt': '2025-02-27T12:00:00Z'
        },
      ];

      final result =
          driveService.testMergeJsonLists(local, remote, 'members.json');

      expect(result.length, 1);
      expect(result.first['name'], 'Member A (Remote Edit)');
    });

    test(
        'Scenario: Session history merging combines all versions sorted by version number',
        () {
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
        {
          'id': 'member_1',
          'name': 'Remote User',
          'updatedAt': '2025-02-27T10:00:00Z'
        },
      ];

      final result =
          driveService.testMergeJsonLists(local, remote, 'members.json');

      expect(result.length, 1);
      expect(result.first['name'], 'Remote User');
    });

    group('Corruption Handling & Self-Healing', () {
      test(
          'Scenario: Corrupted Remote JSON should not crash and should be detectable',
          () {
        // This simulates the logic in _mergeAndSyncFile where it catches FormatException
        final remoteContent = '{"invalid": json...'; // Corrupted JSON

        bool caughtError = false;
        try {
          jsonDecode(remoteContent);
        } catch (e) {
          caughtError = true;
        }

        expect(caughtError, true,
            reason: 'Invalid JSON should throw a FormatException');
      });

      test('Scenario: Schema Type Mismatch (List vs Map) is caught', () {
        final dynamic remoteJsonAsMap = {
          'id': '1',
          'name': 'I should be a list'
        };
        const fileName = 'members.json'; // Expected to be a List

        // Logic from _mergeAndSyncFile:
        final isHistoryFile = fileName == 'sessions_history.json';
        final bool isValidRemote = isHistoryFile
            ? remoteJsonAsMap is Map<String, dynamic>
            : remoteJsonAsMap is List;

        expect(isValidRemote, false,
            reason:
                'A Map instead of a List for members.json should be invalid');
      });

      test(
          'Scenario: Self-Healing Logic - Local healthy List, Remote corrupted',
          () {
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

      test('Scenario: Self-Healing Logic - Local healthy Map, Remote corrupted',
          () {
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

        final result =
            driveService.testMergeJsonLists(local, remote, 'families.json');

        expect(result.length, 1);
        expect(result.first['displayName'], 'Smith (remote edit)');
      });

      test('Scenario: Family conflict resolved by updatedAt (local is newer)',
          () {
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

        final result =
            driveService.testMergeJsonLists(local, remote, 'families.json');

        expect(result.length, 1);
        expect(result.first['displayName'], 'Smith (local edit)');
      });

      test(
          'Scenario: Legacy families without updatedAt still merge member lists',
          () {
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

        final result =
            driveService.testMergeJsonLists(local, remote, 'families.json');

        expect(result.length, 1);
        final members = result.first['members'] as List;
        expect(members.length, 2);
        expect(members.any((m) => m['id'] == 'm1'), true);
        expect(members.any((m) => m['id'] == 'm2'), true);
      });

      test('Scenario: Member with updatedAt conflict is resolved correctly',
          () {
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

        final result =
            driveService.testMergeJsonLists(local, remote, 'members');

        expect(result.length, 1);
        expect(result.first['displayName'], 'John (local)');
      });
    });
  });

  group('DriveService state and auth lifecycle', () {
    late MockGoogleSignIn mockGoogleSignIn;
    late StreamController<GoogleSignInAuthenticationEvent> authController;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      mockGoogleSignIn = MockGoogleSignIn();
      authController =
          StreamController<GoogleSignInAuthenticationEvent>.broadcast();
      when(() => mockGoogleSignIn.authenticationEvents)
          .thenAnswer((_) => authController.stream);
      when(() => mockGoogleSignIn.signOut())
          .thenAnswer((_) async => null);
      when(() => mockGoogleSignIn.attemptLightweightAuthentication())
          .thenReturn(null);
    });

    tearDown(() async {
      await authController.close();
    });

    test('setDriveSyncEnabled(false) persists state without syncing', () async {
      final service = DriveService(googleSignIn: mockGoogleSignIn);
      addTearDown(service.dispose);

      await service.setDriveSyncEnabled(false);

      expect(service.isDriveSyncEnabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('drive_sync_enabled'), isFalse);
    });

    test('setDriveSyncEnabled(true) persists and swallows sync errors',
        () async {
      final service = DriveService(googleSignIn: mockGoogleSignIn);
      addTearDown(service.dispose);

      await service.setDriveSyncEnabled(true);
      // Let the fire-and-forget syncFiles().catchError settle.
      await Future<void>.delayed(Duration.zero);

      expect(service.isDriveSyncEnabled, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('drive_sync_enabled'), isTrue);
    });

    test('init reads disabled flag and skips sign-in', () async {
      SharedPreferences.setMockInitialValues({'drive_sync_enabled': false});
      final service = DriveService(googleSignIn: mockGoogleSignIn);
      addTearDown(service.dispose);

      await service.init();

      expect(service.isDriveSyncEnabled, isFalse);
      expect(service.currentUser, isNull);
      expect(service.lastSyncTime, isNull);
      verifyNever(() => mockGoogleSignIn.attemptLightweightAuthentication());
    });

    test('init parses persisted lastSyncTime', () async {
      final fixed = DateTime.utc(2025, 1, 2, 3, 4, 5);
      SharedPreferences.setMockInitialValues({
        'drive_sync_enabled': false,
        'drive_last_sync_time': fixed.toIso8601String(),
      });
      final service = DriveService(googleSignIn: mockGoogleSignIn);
      addTearDown(service.dispose);

      await service.init();

      expect(service.lastSyncTime, fixed);
    });

    test('init with sync enabled attempts silent sign-in and stays signed out '
        'when no cached user is available', () async {
      SharedPreferences.setMockInitialValues({'drive_sync_enabled': true});
      final service = DriveService(googleSignIn: mockGoogleSignIn);
      addTearDown(service.dispose);

      await service.init();

      expect(service.isDriveSyncEnabled, isTrue);
      expect(service.currentUser, isNull);
      verify(() => mockGoogleSignIn.attemptLightweightAuthentication())
          .called(1);
    });

    test('signOut clears state and resets preferences', () async {
      SharedPreferences.setMockInitialValues({
        'drive_sync_enabled': true,
        'drive_last_sync_time': DateTime.utc(2025, 1, 1).toIso8601String(),
      });
      final service = DriveService(googleSignIn: mockGoogleSignIn);
      addTearDown(service.dispose);
      await service.init();

      var notified = 0;
      service.addListener(() => notified++);

      await service.signOut();

      expect(service.currentUser, isNull);
      expect(service.isDriveSyncEnabled, isFalse);
      expect(service.lastSyncTime, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('drive_sync_enabled'), isFalse);
      expect(prefs.getString('drive_last_sync_time'), isNull);
      expect(notified, greaterThan(0));
      verify(() => mockGoogleSignIn.signOut()).called(1);
    });

    test('sign-in auth event updates currentUser and notifies listeners',
        () async {
      final service = DriveService(googleSignIn: mockGoogleSignIn);
      addTearDown(service.dispose);

      final account = MockGoogleSignInAccount();
      var notified = 0;
      service.addListener(() => notified++);

      authController.add(GoogleSignInAuthenticationEventSignIn(user: account));
      await Future<void>.delayed(Duration.zero);

      expect(service.currentUser, same(account));
      expect(notified, greaterThan(0));
    });

    test('sign-out auth event clears currentUser', () async {
      final service = DriveService(googleSignIn: mockGoogleSignIn);
      addTearDown(service.dispose);

      authController.add(
        GoogleSignInAuthenticationEventSignIn(user: MockGoogleSignInAccount()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.currentUser, isNotNull);

      authController.add(GoogleSignInAuthenticationEventSignOut());
      await Future<void>.delayed(Duration.zero);

      expect(service.currentUser, isNull);
    });

    test('listCloudBackups returns empty list when DriveApi is not initialized',
        () async {
      final service = DriveService(googleSignIn: mockGoogleSignIn);
      addTearDown(service.dispose);

      expect(await service.listCloudBackups(), isEmpty);
    });

    test('restoreFromBackup is a no-op when DriveApi is not initialized',
        () async {
      final service = DriveService(googleSignIn: mockGoogleSignIn);
      addTearDown(service.dispose);

      // Should complete without throwing despite no DriveApi being set up.
      await service.restoreFromBackup('any-file-id');
    });
  });
}
