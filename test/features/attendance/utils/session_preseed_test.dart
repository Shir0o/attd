import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_start_mode.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/utils/session_preseed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final recordedAt = DateTime(2025, 1, 1, 9, 30);
  final members = [
    Member(id: 'a', displayName: 'Alice'),
    Member(
      id: 'b',
      displayName: 'Bob',
      defaultStatus: AttendanceStatus.present,
    ),
    Member(id: '', displayName: 'NoId'), // skipped
  ];

  test('allAbsent marks every (id-bearing) member absent', () {
    final records = buildPreseededRecords(
      members: members,
      mode: AttendanceStartMode.allAbsent,
      recordedAt: recordedAt,
    );
    expect(records, hasLength(2));
    expect(records.every((r) => r.status == AttendanceStatus.absent), isTrue);
    expect(records.first.recordedBy, 'System (Preseed)');
  });

  test('allPresent marks every member present', () {
    final records = buildPreseededRecords(
      members: members,
      mode: AttendanceStartMode.allPresent,
      recordedAt: recordedAt,
    );
    expect(records, hasLength(2));
    expect(records.every((r) => r.status == AttendanceStatus.present), isTrue);
  });

  test('perMemberDefault respects each member.defaultStatus', () {
    final records = buildPreseededRecords(
      members: members,
      mode: AttendanceStartMode.perMemberDefault,
      recordedAt: recordedAt,
    );
    final byId = {for (final r in records) r.memberId: r};
    expect(byId['a']!.status, AttendanceStatus.absent);
    expect(byId['b']!.status, AttendanceStatus.present);
  });

  test('records carry recordedAt and attendee name', () {
    final records = buildPreseededRecords(
      members: members.take(1),
      mode: AttendanceStartMode.allAbsent,
      recordedAt: recordedAt,
    );
    expect(records.single.recordedAt, recordedAt);
    expect(records.single.attendee, 'Alice');
    expect(records.single.memberId, 'a');
  });

  group('perMemberDefault with past-pattern history', () {
    Session sess(String id, Map<String, AttendanceStatus> records) {
      final t = DateTime(2026, 1, 1);
      return Session(
        id: id,
        title: 't',
        sessionDate: t,
        createdAt: t,
        updatedAt: t,
        createdBy: 'test',
        records: [
          for (final e in records.entries)
            SessionRecord(
              memberId: e.key,
              attendee: e.key,
              status: e.value,
              recordedAt: t,
              recordedBy: 'User',
            ),
        ],
      );
    }

    test('preseeds consistent members and skips mixed-pattern ones', () {
      final history = <Session>[
        for (var i = 0; i < 5; i++)
          sess('s$i', {
            'a': AttendanceStatus.present,
            'b': AttendanceStatus.absent,
            'c': i.isEven
                ? AttendanceStatus.present
                : AttendanceStatus.absent,
          }),
      ];
      final m = [
        Member(id: 'a', displayName: 'A'),
        Member(id: 'b', displayName: 'B'),
        Member(id: 'c', displayName: 'C'),
      ];
      final records = buildPreseededRecords(
        members: m,
        mode: AttendanceStartMode.perMemberDefault,
        recordedAt: recordedAt,
        recentSessions: history,
      );
      final byId = {for (final r in records) r.memberId: r.status};
      expect(byId['a'], AttendanceStatus.present);
      expect(byId['b'], AttendanceStatus.absent);
      // c is mixed → not preseeded.
      expect(byId.containsKey('c'), isFalse);
    });

    test('falls back to static defaultStatus when no history given', () {
      final records = buildPreseededRecords(
        members: members,
        mode: AttendanceStartMode.perMemberDefault,
        recordedAt: recordedAt,
      );
      final byId = {for (final r in records) r.memberId: r.status};
      expect(byId['a'], AttendanceStatus.absent);
      expect(byId['b'], AttendanceStatus.present);
    });
  });

  group('AttendanceStartMode Extension', () {
    test('label, shortLabel and description are correct', () {
      for (final mode in AttendanceStartMode.values) {
        expect(mode.label, isNotEmpty);
        expect(mode.shortLabel, isNotEmpty);
        expect(mode.description, isNotEmpty);
      }
    });
  });
}
