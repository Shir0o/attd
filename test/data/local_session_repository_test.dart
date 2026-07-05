import 'dart:convert';
import 'dart:io';

import 'package:attendance_tracker/data/local_session_repository.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalJsonSessionRepository', () {
    late Directory tempDir;
    late LocalJsonSessionRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('session_repo_test');
      repository = LocalJsonSessionRepository(storagePath: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('loadSessions returns empty list initially', () async {
      final sessions = await repository.loadSessions();
      expect(sessions, isEmpty);
    });

    test('createSession adds a session', () async {
      final now = DateTime.now();
      final records = [
        SessionRecord(
          memberId: 'm1',
          attendee: 'John',
          status: AttendanceStatus.present,
          recordedAt: now,
          recordedBy: 'Admin',
        ),
      ];

      final session = await repository.createSession(
        title: 'New Session',
        sessionDate: now,
        actor: 'Admin',
        records: records,
      );

      expect(session.title, 'New Session');
      expect(session.records.length, 1);

      final loaded = await repository.loadSessions();
      expect(loaded.length, 1);
      expect(loaded.first.id, session.id);
    });

    test('saveSnapshot updates session and history', () async {
      final now = DateTime.now();
      final session = await repository.createSession(
        title: 'Original',
        sessionDate: now,
        actor: 'Admin',
        records: [],
      );

      final updated = session.copyWith(title: 'Updated');
      await repository.saveSnapshot(updated, actor: 'Admin');

      final loaded = await repository.findSessionById(session.id);
      expect(loaded?.title, 'Updated');
      expect(loaded?.currentVersion, 2);

      final history = await repository.history(session.id);
      expect(history.length, 2); // Version 2 (newest) and Version 1
      expect(history.first.version, 2);
      expect(history.last.version, 1);
    });

    test('deleteSession soft deletes session and preserves history', () async {
      final now = DateTime.now();
      final session = await repository.createSession(
        title: 'To Delete',
        sessionDate: now,
        actor: 'Admin',
        records: [],
      );

      await repository.deleteSession(session.id, actor: 'Admin');
      await repository.refresh();

      final loaded = await repository.loadSessions();
      expect(loaded, isEmpty);

      // History should still exist for soft-deleted session (needed for sync)
      final history = await repository.history(session.id);
      expect(history, isNotEmpty);

      // Verify it still exists in the raw file
      final file = File('${tempDir.path}/sessions.json');
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      expect(jsonList.length, 1);
      expect(jsonList.first['deletedAt'], isNotNull);
    });

    test('pruneSoftDeleted removes old deleted sessions', () async {
      final now = DateTime.now();
      final session = await repository.createSession(
        title: 'To Prune',
        sessionDate: now,
        actor: 'Admin',
        records: [],
      );

      // Soft delete it
      await repository.deleteSession(session.id, actor: 'Admin');

      // Threshold is in the future relative to deletion time, so it should be pruned
      final threshold = now.add(const Duration(seconds: 1));
      await repository.pruneSoftDeleted(threshold);
      await repository.refresh();

      // Verify it's gone from the raw file
      final file = File('${tempDir.path}/sessions.json');
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      expect(jsonList, isEmpty);

      // History should also be gone
      final history = await repository.history(session.id);
      expect(history, isEmpty);
    });

    test('duplicate creates a copy with new ID', () async {
      final now = DateTime.now();
      final original = await repository.createSession(
        title: 'Original',
        sessionDate: now,
        actor: 'Admin',
        records: [
          SessionRecord(
            memberId: 'm1',
            attendee: 'John',
            status: AttendanceStatus.present,
            recordedAt: now,
            recordedBy: 'Admin',
          ),
        ],
      );

      final duplicate =
          await repository.duplicate(original.id, actor: 'Tester');

      expect(duplicate.id, isNot(original.id));
      expect(duplicate.title, contains('Original (redo)'));
      expect(duplicate.records.length, 1);
      expect(duplicate.records.first.recordedBy, 'Tester');
    });

    test('persistence works across instances', () async {
      final now = DateTime.now();
      await repository.createSession(
        title: 'Persisted',
        sessionDate: now,
        actor: 'Admin',
        records: [],
      );

      // Create new instance pointing to same path
      final newRepo = LocalJsonSessionRepository(storagePath: tempDir.path);
      final sessions = await newRepo.loadSessions();

      expect(sessions.length, 1);
      expect(sessions.first.title, 'Persisted');
    });

    test('loadSessions handles empty and malformed files', () async {
      final file = File('${tempDir.path}/sessions.json');
      await file.writeAsString('');

      expect(await repository.loadSessions(), isEmpty);

      await file.writeAsString('{not json');
      await repository.refresh();

      expect(await repository.loadSessions(), isEmpty);
    });

    test('findSessionById returns null for missing sessions', () async {
      expect(await repository.findSessionById('missing'), isNull);
    });

    test('duplicate throws when the source session is missing', () async {
      await expectLater(
        repository.duplicate('missing', actor: 'Tester'),
        throwsStateError,
      );
    });

    test('streamSessions emits initial and updated sessions', () async {
      final emissions = <List<Session>>[];
      final subscription = repository.streamSessions().listen(emissions.add);

      await pumpEventQueue();
      final session = await repository.createSession(
        title: 'Streamed',
        sessionDate: DateTime.now(),
        actor: 'Admin',
        records: const [],
      );
      await repository.saveSnapshot(
        session.copyWith(title: 'Streamed Update'),
        actor: 'Admin',
      );
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions.first, isEmpty);
      expect(emissions.last.single.title, 'Streamed Update');
    });

    test('migrateRecords updates sessions and history snapshots', () async {
      final now = DateTime(2026, 5, 17);
      final session = await repository.createSession(
        title: 'Migration',
        sessionDate: now,
        actor: 'Admin',
        records: [
          SessionRecord(
            attendee: 'Alice',
            status: AttendanceStatus.present,
            recordedAt: now,
            recordedBy: 'Admin',
          ),
          SessionRecord(
            memberId: 'existing',
            attendee: 'Bob',
            status: AttendanceStatus.absent,
            recordedAt: now,
            recordedBy: 'Admin',
          ),
        ],
      );
      await repository.saveSnapshot(session.copyWith(title: 'Migration 2'),
          actor: 'Admin');

      await repository.migrateRecords({'Alice': 'alice-id', 'Bob': 'bob-id'});

      final loaded = await repository.findSessionById(session.id);
      expect(loaded!.records.first.memberId, 'alice-id');
      expect(loaded.records.last.memberId, 'existing');

      final history = await repository.history(session.id);
      expect(history, hasLength(2));
      expect(history.first.snapshot.records.first.memberId, 'alice-id');
      expect(history.last.snapshot.records.first.memberId, 'alice-id');
    });

    test('migrateRecords is a no-op when no names match', () async {
      final now = DateTime(2026, 5, 17);
      await repository.createSession(
        title: 'No Migration',
        sessionDate: now,
        actor: 'Admin',
        records: [
          SessionRecord(
            attendee: 'Alice',
            status: AttendanceStatus.present,
            recordedAt: now,
            recordedBy: 'Admin',
          ),
        ],
      );

      await repository.migrateRecords({'Other': 'other-id'});

      final loaded = await repository.loadSessions();
      expect(loaded.single.records.single.memberId, isNull);
    });

    test('loadSessions recovers from healthy backup file when main file is corrupted', () async {
      final mainFile = File('${tempDir.path}/sessions.json');
      final backupFile = File('${tempDir.path}/sessions.json.bak');

      // Create a valid sessions backup content
      final now = DateTime.now();
      final sessions = [
        Session(
          id: 'test-id',
          title: 'From Backup',
          sessionDate: now,
          records: [],
          createdAt: now,
          updatedAt: now,
          createdBy: 'Admin',
          currentVersion: 1,
        )
      ];
      await backupFile.writeAsString(jsonEncode(sessions.map((e) => e.toJson()).toList()));

      // Corrupt the main file
      await mainFile.writeAsString('{corrupted json');

      await repository.refresh();
      final loaded = await repository.loadSessions();

      expect(loaded.length, 1);
      expect(loaded.first.title, 'From Backup');
      
      // Verify main file has been healed
      expect(mainFile.existsSync(), isTrue);
      expect(jsonDecode(mainFile.readAsStringSync()), isList);
    });

    test('loadSessions recovers from healthy backup file when main file is missing', () async {
      final mainFile = File('${tempDir.path}/sessions.json');
      final backupFile = File('${tempDir.path}/sessions.json.bak');

      if (mainFile.existsSync()) {
        mainFile.deleteSync();
      }

      // Create a valid sessions backup content
      final now = DateTime.now();
      final sessions = [
        Session(
          id: 'test-id',
          title: 'From Backup 2',
          sessionDate: now,
          records: [],
          createdAt: now,
          updatedAt: now,
          createdBy: 'Admin',
          currentVersion: 1,
        )
      ];
      await backupFile.writeAsString(jsonEncode(sessions.map((e) => e.toJson()).toList()));

      await repository.refresh();
      final loaded = await repository.loadSessions();

      expect(loaded.length, 1);
      expect(loaded.first.title, 'From Backup 2');
      
      // Verify main file has been restored
      expect(mainFile.existsSync(), isTrue);
    });

    test('fetchAllSessions and saveSessions work correctly', () async {
      final now = DateTime.now();
      final sessions = [
        Session(
          id: 's-1',
          title: 'Custom Session',
          sessionDate: now,
          records: [],
          createdAt: now,
          updatedAt: now,
          createdBy: 'Tester',
          currentVersion: 1,
        )
      ];
      await repository.saveSessions(sessions);
      final fetched = await repository.fetchAllSessions();
      expect(fetched.length, 1);
      expect(fetched.first.title, 'Custom Session');
    });
  });
}
