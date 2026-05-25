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
}
