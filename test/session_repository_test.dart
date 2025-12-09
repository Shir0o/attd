import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  LocalSessionRepository buildRepository() {
    var current = DateTime(2024, 1, 1, 9);
    return LocalSessionRepository(
      customFactory: databaseFactoryFfi,
      dbPathProvider: () async => inMemoryDatabasePath,
      clock: () => current,
      seedSessions: const [],
    );
  }

  SessionRecord buildRecord(String name, AttendanceStatus status) {
    return SessionRecord(
      attendee: name,
      status: status,
      recordedAt: DateTime(2024, 1, 1, 9),
      recordedBy: 'Tester',
    );
  }

  test('creates and lists sessions', () async {
    final repository = buildRepository();

    await repository.createSession(
      title: 'Team Sync',
      sessionDate: DateTime(2024, 1, 1),
      actor: 'Tester',
      records: [
        buildRecord('Alana Rivera', AttendanceStatus.present),
        buildRecord('Priya Patel', AttendanceStatus.absent),
      ],
    );

    final sessions = await repository.loadSessions();
    expect(sessions.length, 1);
    expect(sessions.first.records.length, 2);
    expect(sessions.first.currentVersion, 1);
  });

  test('saves revisions and reverts to previous snapshot', () async {
    final repository = buildRepository();

    final created = await repository.createSession(
      title: 'Review',
      sessionDate: DateTime(2024, 1, 1),
      actor: 'Tester',
      records: [buildRecord('Minh Nguyen', AttendanceStatus.present)],
    );

    final updated = await repository.saveSnapshot(
      created.copyWith(
        records: [
          ...created.records,
          buildRecord('Aarav Patel', AttendanceStatus.partial),
        ],
      ),
      actor: 'Tester',
    );

    expect(updated.currentVersion, 2);
    expect(updated.records.length, 2);

    final reverted = await repository.revertToPrevious(
      created.id,
      actor: 'Tester',
    );
    expect(reverted, isNotNull);
    expect(reverted!.currentVersion, 3);
    expect(reverted.records.length, created.records.length);
  });

  test('duplicates sessions with redo suffix', () async {
    final repository = buildRepository();

    final created = await repository.createSession(
      title: 'Planning',
      sessionDate: DateTime(2024, 1, 2),
      actor: 'Tester',
      records: [buildRecord('Alana', AttendanceStatus.present)],
    );

    final duplicate = await repository.duplicate(created.id, actor: 'Tester');

    expect(duplicate.id, isNot(equals(created.id)));
    expect(duplicate.title.contains('(redo)'), isTrue);
    expect(duplicate.currentVersion, 1);
    expect(duplicate.records.first.recordedBy, 'Tester');
  });
}
