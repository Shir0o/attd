import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FirestoreSessionRepository buildRepository() {
    return FirestoreSessionRepository(
      firestore: FakeFirebaseFirestore(),
      seedSessions: [],
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

    // Wait slightly to ensure timestamp difference if needed, though fake firestore might be instant.
    // For specific ordering relying on time, we might need manual clock control if we were injecting it,
    // but FirestoreSessionRepository uses DateTime.now() internally which is hard to mock without dependency injection.
    // However, for typical versioning logic which relies on version numbers, it should be fine.

    final updated = await repository.saveSnapshot(
      created.copyWith(
        records: [
          ...created.records,
          buildRecord('Aarav Patel', AttendanceStatus.absent),
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
