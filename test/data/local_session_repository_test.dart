import 'dart:io';

import 'package:attendance_tracker/data/local_session_repository.dart';
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

    test('deleteSession removes session and history', () async {
      final now = DateTime.now();
      final session = await repository.createSession(
        title: 'To Delete',
        sessionDate: now,
        actor: 'Admin',
        records: [],
      );

      await repository.deleteSession(session.id, actor: 'Admin');

      final loaded = await repository.loadSessions();
      expect(loaded, isEmpty);

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
            attendee: 'John',
            status: AttendanceStatus.present,
            recordedAt: now,
            recordedBy: 'Admin',
          ),
        ],
      );

      final duplicate = await repository.duplicate(original.id, actor: 'Tester');

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
  });
}
