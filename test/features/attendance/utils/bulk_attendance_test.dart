import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/utils/bulk_attendance.dart';
import 'package:flutter_test/flutter_test.dart';

Session _session(String id, Map<String, AttendanceStatus> statuses) {
  final now = DateTime(2026, 1, 1);
  return Session(
    id: id,
    title: 't',
    sessionDate: now,
    createdAt: now,
    updatedAt: now,
    createdBy: 'test',
    records: [
      for (final entry in statuses.entries)
        SessionRecord(
          memberId: entry.key,
          attendee: entry.key,
          status: entry.value,
          recordedAt: now,
          recordedBy: 'User',
        ),
    ],
  );
}

Member _member(String id) => Member(id: id, displayName: id);

void main() {
  group('applyBulkSmartRecords', () {
    final now = DateTime(2026, 6, 1);

    test('resolves present/absent from history and skips mixed members', () {
      final members = [_member('reg'), _member('skip'), _member('gone')];
      final history = [
        for (var i = 0; i < 4; i++)
          _session('s$i', {
            'reg': AttendanceStatus.present,
            'gone': AttendanceStatus.absent,
            // 'skip' alternates → mixed → ResolvedDefault.ask
            'skip': i.isEven
                ? AttendanceStatus.present
                : AttendanceStatus.absent,
          }),
      ];

      final result = applyBulkSmartRecords(
        previousRecords: const [],
        members: members,
        recentSessions: history,
        recordedAt: now,
      );

      expect(result.resolved, 2);
      final byId = {for (final r in result.records) r.memberId: r.status};
      expect(byId['reg'], AttendanceStatus.present);
      expect(byId['gone'], AttendanceStatus.absent);
      // 'skip' has no record — left for the user to decide.
      expect(byId.containsKey('skip'), isFalse);
    });

    test('keeps the existing status for members with no resolution', () {
      final existing = SessionRecord(
        memberId: 'skip',
        attendee: 'skip',
        status: AttendanceStatus.present,
        recordedAt: now,
        recordedBy: 'User',
      );
      final history = [
        _session('s1', {'skip': AttendanceStatus.present}),
        _session('s2', {'skip': AttendanceStatus.absent}),
      ]; // 2 samples → ask

      final result = applyBulkSmartRecords(
        previousRecords: [existing],
        members: [_member('skip')],
        recentSessions: history,
        recordedAt: now,
      );

      expect(result.resolved, 0);
      expect(result.records, [existing]);
    });

    test('overwrites the prior record for a resolved member', () {
      final stale = SessionRecord(
        memberId: 'reg',
        attendee: 'reg',
        status: AttendanceStatus.absent,
        recordedAt: now,
        recordedBy: 'User',
      );
      final history = [
        for (var i = 0; i < 4; i++)
          _session('s$i', {'reg': AttendanceStatus.present}),
      ];

      final result = applyBulkSmartRecords(
        previousRecords: [stale],
        members: [_member('reg')],
        recentSessions: history,
        recordedAt: now,
      );

      expect(result.records.length, 1);
      expect(result.records.single.status, AttendanceStatus.present);
    });
  });
}
