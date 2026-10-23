import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:attendance_tracker/features/settings/application/app_lock_controller.dart';
import 'package:attendance_tracker/features/settings/data/drive_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';


class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockAppLockController extends Mock implements AppLockController {}

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

    test('SyncStats reports changes as ordered tags including updated/deleted and families', () {
      final stats = SyncStats()
        ..newSessions = 2
        ..newEvents = 1
        ..newMembers = 3
        ..newFamilies = 1;

      expect(stats.hasChanges, isTrue);
      expect(stats.toTags(), [
        '+2 Sessions',
        '+1 Events',
        '+3 Members',
        '+1 Families',
      ]);

      final updateDeleteStats = SyncStats()
        ..updatedSessions = 1
        ..deletedEvents = 2
        ..updatedMembers = 1
        ..deletedFamilies = 1;
      expect(updateDeleteStats.toTags(), [
        '1 Sessions',
        '2 Events',
        '1 Members',
        '1 Families',
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
        {
          'id': 'session_2',
          'title': 'Remote',
          'sessionDate': '2026-10-18T10:00:00.000',
          'records': [
            {'status': 'present'},
            {'status': 'absent'},
          ],
        },
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
      expect(
        stats.itemChanges,
        contains('Added session · Remote (Oct 18) · 1 present, 1 absent'),
      );
    });

    test('Scenario: Local-only additions and updatedAt conflicts record exact item changes', () {
      final stats = SyncStats();
      final local = [
        {
          'id': 'event_1',
          'title': 'Youth Group (Updated)',
          'updatedAt': '2026-10-20T12:00:00Z',
        },
        {
          'id': 'event_2',
          'title': 'Bible Study',
          'updatedAt': '2026-10-20T12:00:00Z',
        },
        {
          'id': 'event_3',
          'title': 'Deleted Event',
          'updatedAt': '2026-10-20T12:00:00Z',
          'deletedAt': '2026-10-20T12:00:00Z',
        },
      ];
      final remote = [
        {
          'id': 'event_1',
          'title': 'Youth Group',
          'updatedAt': '2026-10-19T12:00:00Z',
        },
        {
          'id': 'event_3',
          'title': 'Deleted Event',
          'updatedAt': '2026-10-19T12:00:00Z',
        },
      ];

      final result = driveService.testMergeJsonLists(
        local,
        remote,
        'events.json',
        stats: stats,
      );

      expect(result.length, 3);
      expect(stats.newEvents, 1);
      expect(stats.updatedEvents, 1);
      expect(stats.deletedEvents, 1);
      expect(stats.hasChanges, isTrue);
      expect(
        stats.itemChanges,
        containsAll([
          'Added event · Bible Study',
          'Updated event · Youth Group (Updated)',
          'Deleted event · Deleted Event',
        ]),
      );
    });

    test('Scenario: Sessions, families, and members updated/deleted record exact item changes', () {
      final sessionStats = SyncStats();
      driveService.testMergeJsonLists(
        [
          {
            'id': 's1',
            'title': 'Morning Prayer',
            'sessionDate': '2026-10-18T10:00:00Z',
            'updatedAt': '2026-10-19T10:00:00Z',
            'records': [
              {'status': 'excused'},
            ],
          },
          {
            'id': 's2',
            'title': 'Old Session',
            'sessionDate': '2026-10-10T10:00:00Z',
            'updatedAt': '2026-10-19T10:00:00Z',
            'deletedAt': '2026-10-19T10:00:00Z',
          },
        ],
        [
          {
            'id': 's1',
            'title': 'Morning Prayer',
            'sessionDate': '2026-10-18T10:00:00Z',
            'updatedAt': '2026-10-18T10:00:00Z',
          },
          {
            'id': 's2',
            'title': 'Old Session',
            'sessionDate': '2026-10-10T10:00:00Z',
            'updatedAt': '2026-10-18T10:00:00Z',
          },
        ],
        'sessions.json',
        stats: sessionStats,
      );
      expect(sessionStats.updatedSessions, 1);
      expect(sessionStats.deletedSessions, 1);
      expect(
        sessionStats.itemChanges,
        containsAll([
          'Updated session · Morning Prayer (Oct 18) · 1 marks',
          'Deleted session · Old Session (Oct 10)',
        ]),
      );

      final familyStats = SyncStats();
      driveService.testMergeJsonLists(
        [
          {
            'id': 'f1',
            'displayName': 'Smith Family',
            'updatedAt': '2026-10-20T10:00:00Z',
            'members': [
              {
                'id': 'm1',
                'displayName': 'Alice Updated',
                'updatedAt': '2026-10-20T10:00:00Z',
              },
              {
                'id': 'm2',
                'displayName': 'Bob Deleted',
                'updatedAt': '2026-10-20T10:00:00Z',
                'deletedAt': '2026-10-20T10:00:00Z',
              },
            ],
          },
          {
            'id': 'f2',
            'displayName': 'Deleted Family',
            'updatedAt': '2026-10-20T10:00:00Z',
            'deletedAt': '2026-10-20T10:00:00Z',
            'members': [],
          },
          {
            'id': 'f3',
            'displayName': 'New Family',
            'updatedAt': '2026-10-20T10:00:00Z',
            'members': [
              {'id': 'm3', 'displayName': 'Charlie'},
            ],
          },
        ],
        [
          {
            'id': 'f1',
            'displayName': 'Smith',
            'updatedAt': '2026-10-19T10:00:00Z',
            'members': [
              {
                'id': 'm1',
                'displayName': 'Alice',
                'updatedAt': '2026-10-19T10:00:00Z',
              },
              {
                'id': 'm2',
                'displayName': 'Bob Deleted',
                'updatedAt': '2026-10-19T10:00:00Z',
              },
            ],
          },
          {
            'id': 'f2',
            'displayName': 'Deleted Family',
            'updatedAt': '2026-10-19T10:00:00Z',
            'members': [],
          },
        ],
        'families.json',
        stats: familyStats,
      );
      expect(familyStats.newFamilies, 1);
      expect(familyStats.updatedFamilies, 1);
      expect(familyStats.deletedFamilies, 1);
      expect(familyStats.newMembers, 1);
      expect(familyStats.updatedMembers, 1);
      expect(familyStats.deletedMembers, 1);
      expect(
        familyStats.itemChanges,
        containsAll([
          'Added family · New Family',
          'Updated family · Smith Family',
          'Deleted family · Deleted Family',
          'Updated member · Alice Updated (Smith Family)',
          'Deleted member · Bob Deleted (Smith Family)',
          'Added member · Charlie (New Family)',
        ]),
      );
    });

    test('Scenario: SyncStats caps itemChanges and tracks overflow count', () {
      final stats = SyncStats();
      for (var i = 0; i < SyncStats.maxRecordedItemChanges + 5; i++) {
        stats.addItemChange('Added member · Person $i');
      }
      expect(stats.itemChanges.length, SyncStats.maxRecordedItemChanges);
      expect(stats.overflowItemChanges, 5);
    });

    test('Scenario: selectBackupsToThin enforces 10-snapshot floor, 7-day full, 8-30d daily, >30d prune', () {
      final now = DateTime(2026, 10, 23, 12, 0);
      final backups = <drive.File>[
        // 10 recent backups within last 3 days (protected floor)
        for (var i = 0; i < 10; i++)
          drive.File()
            ..id = 'recent_$i'
            ..createdTime = now.subtract(Duration(hours: i * 4)),
        // 2 backups on day 5 (within 7 days -> both kept)
        drive.File()
          ..id = 'day5_a'
          ..createdTime = DateTime(2026, 10, 18, 15, 0),
        drive.File()
          ..id = 'day5_b'
          ..createdTime = DateTime(2026, 10, 18, 9, 0),
        // 2 backups on day 14 (between 7 and 30 days -> latest kept, older thinned)
        drive.File()
          ..id = 'day14_latest'
          ..createdTime = DateTime(2026, 10, 9, 18, 0),
        drive.File()
          ..id = 'day14_older'
          ..createdTime = DateTime(2026, 10, 9, 8, 0),
        // 1 backup on day 45 (>30 days -> thinned)
        drive.File()
          ..id = 'day45_old'
          ..createdTime = DateTime(2026, 9, 1, 12, 0),
      ];

      final toThin = DriveService.selectBackupsToThin(backups, now: now);
      expect(toThin, ['day14_older', 'day45_old']);
    });

    test('Scenario: Soft-deleted remote items are not resurrected when purged locally', () {
      final stats = SyncStats();
      final local = [
        {'id': 'session_active', 'title': 'Active Local'},
      ];
      final remote = [
        {'id': 'session_active', 'title': 'Active Local'},
        {
          'id': 'session_deleted',
          'title': 'Deleted on Remote',
          'deletedAt': '2026-06-25T01:52:16.892',
        },
      ];

      final result = driveService.testMergeJsonLists(
        local,
        remote,
        'sessions.json',
        stats: stats,
      );

      expect(result.length, 1);
      expect(result.first['id'], 'session_active');
      expect(stats.newSessions, 0);
      expect(stats.hasChanges, isFalse);
    });

    test('Scenario: Soft-deleted remote members are not resurrected when purged locally', () {
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
            {'id': 'member_1', 'displayName': 'Alice'},
            {
              'id': 'member_deleted',
              'displayName': 'Ghost',
              'deletedAt': '2026-06-25T01:52:16.892',
            },
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
      expect(members.map((m) => m['id']), ['member_1']);
      expect(stats.newMembers, 0);
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
          .thenAnswer((_) async {});
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

    test('signIn throws UnsupportedError when supportsAuthenticate is false', () async {
      when(() => mockGoogleSignIn.supportsAuthenticate()).thenReturn(false);
      final service = DriveService(googleSignIn: mockGoogleSignIn);
      addTearDown(service.dispose);

      expect(() => service.signIn(), throwsUnsupportedError);
    });

    test('signInSilently handles null attemptLightweightAuthentication', () async {
      when(() => mockGoogleSignIn.attemptLightweightAuthentication()).thenReturn(null);
      final service = DriveService(googleSignIn: mockGoogleSignIn);
      addTearDown(service.dispose);

      await service.signInSilently();
      expect(service.currentUser, isNull);
    });

    test('signInSilently toggles external auth flag on AppLockController', () async {
      final mockAppLockController = MockAppLockController();
      when(() => mockAppLockController.setExternalAuthInProgress(any()))
          .thenReturn(null);
      final service = DriveService(
        googleSignIn: mockGoogleSignIn,
        appLockController: mockAppLockController,
      );
      addTearDown(service.dispose);

      await service.signInSilently();

      verify(() => mockAppLockController.setExternalAuthInProgress(true))
          .called(1);
      verify(() => mockAppLockController.setExternalAuthInProgress(false))
          .called(1);
    });

    group('Connection Abort & Transient Network Errors', () {
      test('isConnectionAbortError identifies ClientException and SocketException aborts', () {
        expect(
          isConnectionAbortError(
            http.ClientException('Software caused connection abort'),
          ),
          isTrue,
        );
        expect(
          isConnectionAbortError(
            const SocketException('Software caused connection abort'),
          ),
          isTrue,
        );
        expect(
          isConnectionAbortError(
            const SocketException('Connection reset by peer'),
          ),
          isTrue,
        );
        expect(
          isConnectionAbortError(
            const HttpException('Connection closed before full header was received'),
          ),
          isFalse,
        );
        expect(
          isConnectionAbortError(Exception('Generic error')),
          isFalse,
        );
      });

      test('isTransientNetworkError identifies transient exceptions', () {
        expect(
          isTransientNetworkError(http.ClientException('Network drop')),
          isTrue,
        );
        expect(
          isTransientNetworkError(const SocketException('No route to host')),
          isTrue,
        );
        expect(
          isTransientNetworkError(const HttpException('Http error')),
          isTrue,
        );
        expect(
          isTransientNetworkError(TimeoutException('Request timed out')),
          isTrue,
        );
        expect(
          isTransientNetworkError(Exception('Business logic error')),
          isFalse,
        );
      });

      test('SyncInterruptedException formats message correctly', () {
        final ex = SyncInterruptedException('Sync paused', Exception('Abort'));
        expect(ex.message, 'Sync paused');
        expect(ex.toString(), contains('SyncInterruptedException: Sync paused'));
        expect(ex.toString(), contains('Exception: Abort'));
      });

      test('testRetryDriveOperation uses delayOverride and retries transient errors', () async {
        final service = DriveService(googleSignIn: mockGoogleSignIn);
        addTearDown(service.dispose);

        int attempts = 0;
        final delays = <Duration>[];

        final result = await service.testRetryDriveOperation(
          () async {
            attempts++;
            if (attempts < 3) {
              throw http.ClientException('Transient error');
            }
            return 'success';
          },
          delayOverride: (d) async => delays.add(d),
        );

        expect(result, 'success');
        expect(attempts, 3);
        expect(delays.length, 2);
        expect(delays[0], const Duration(milliseconds: 500));
        expect(delays[1], const Duration(milliseconds: 1000));
      });

      test('testRetryDriveOperation rethrows immediately on non-transient errors', () async {
        final service = DriveService(googleSignIn: mockGoogleSignIn);
        addTearDown(service.dispose);

        int attempts = 0;
        expect(
          () => service.testRetryDriveOperation(() async {
            attempts++;
            throw FormatException('Fatal parse error');
          }),
          throwsFormatException,
        );

        expect(attempts, 1);
      });

      test('signIn toggles external auth flag on AppLockController', () async {
        final mockAppLockController = MockAppLockController();
        when(() => mockAppLockController.setExternalAuthInProgress(any())).thenReturn(null);
        final serviceWithLock = DriveService(
          googleSignIn: mockGoogleSignIn,
          appLockController: mockAppLockController,
        );
        addTearDown(serviceWithLock.dispose);

        when(() => mockGoogleSignIn.supportsAuthenticate()).thenReturn(false);

        await expectLater(
          serviceWithLock.signIn(),
          throwsA(isA<UnsupportedError>()),
        );

        verify(() => mockAppLockController.setExternalAuthInProgress(true)).called(1);
        verify(() => mockAppLockController.setExternalAuthInProgress(false)).called(1);
      });
    });

    group('isAuthExpiredError', () {
      test('identifies DetailedApiRequestError status 401', () {
        expect(isAuthExpiredError(drive.DetailedApiRequestError(401, 'Unauthorized')), isTrue);
      });

      test('identifies DetailedApiRequestError messages', () {
        expect(isAuthExpiredError(drive.DetailedApiRequestError(403, 'Invalid credentials')), isTrue);
        expect(isAuthExpiredError(drive.DetailedApiRequestError(403, 'Bearer token expired')), isTrue);
        expect(isAuthExpiredError(drive.DetailedApiRequestError(403, 'invalid token provided')), isTrue);
        expect(isAuthExpiredError(drive.DetailedApiRequestError(403, 'Token expired at 12:00')), isTrue);
        expect(isAuthExpiredError(drive.DetailedApiRequestError(403, 'auth_token_expired')), isTrue);
        expect(isAuthExpiredError(drive.DetailedApiRequestError(403, 'quota exceeded')), isFalse);
      });

      test('identifies string-based 401 errors', () {
        expect(isAuthExpiredError(Exception('401 Invalid credentials')), isTrue);
        expect(isAuthExpiredError(Exception('401 Bearer error')), isTrue);
        expect(isAuthExpiredError(Exception('401 Unauthorized')), isTrue);
        expect(isAuthExpiredError(Exception('401 not found')), isFalse);
        expect(isAuthExpiredError(Exception('500 server error')), isFalse);
      });
    });
  });
}



