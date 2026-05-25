import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/utils/member_default_resolver.dart';
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

void main() {
  group('resolveDefault', () {
    test('returns ask when fewer than 3 samples', () {
      final sessions = [
        _session('s1', {'m1': AttendanceStatus.present}),
        _session('s2', {'m1': AttendanceStatus.present}),
      ];
      expect(resolveDefault('m1', sessions), ResolvedDefault.ask);
    });

    test('returns present when ≥80% are present', () {
      final sessions = [
        for (var i = 0; i < 5; i++)
          _session('s$i', {'m1': AttendanceStatus.present}),
      ];
      expect(resolveDefault('m1', sessions), ResolvedDefault.present);
    });

    test('returns absent when ≥80% are absent', () {
      final sessions = [
        for (var i = 0; i < 5; i++)
          _session('s$i', {'m1': AttendanceStatus.absent}),
      ];
      expect(resolveDefault('m1', sessions), ResolvedDefault.absent);
    });

    test('returns ask for mixed pattern', () {
      final sessions = [
        _session('s1', {'m1': AttendanceStatus.present}),
        _session('s2', {'m1': AttendanceStatus.absent}),
        _session('s3', {'m1': AttendanceStatus.present}),
        _session('s4', {'m1': AttendanceStatus.absent}),
      ];
      expect(resolveDefault('m1', sessions), ResolvedDefault.ask);
    });

    test('only consults the last 8 sessions', () {
      // 8 absent (recent) + 4 present (older) → absent.
      final sessions = [
        for (var i = 0; i < 8; i++)
          _session('s$i', {'m1': AttendanceStatus.absent}),
        for (var i = 0; i < 4; i++)
          _session('o$i', {'m1': AttendanceStatus.present}),
      ];
      expect(resolveDefault('m1', sessions), ResolvedDefault.absent);
    });

    test('ignores sessions where the member is not recorded', () {
      final sessions = [
        _session('s1', {'other': AttendanceStatus.present}),
        _session('s2', {'other': AttendanceStatus.present}),
      ];
      expect(resolveDefault('m1', sessions), ResolvedDefault.ask);
    });
  });
}
