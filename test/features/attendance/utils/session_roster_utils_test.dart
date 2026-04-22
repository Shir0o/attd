import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/utils/session_roster_utils.dart';

void main() {
  group('SessionRoster', () {
    final member1 = Member(id: 'm1', displayName: 'Alice');
    final member2 = Member(id: 'm2', displayName: 'Bob');
    final baseMembers = [member1, member2];

    test('should resolve records by memberId', () {
      final session = Session(
        id: 's1',
        title: 'Session 1',
        sessionDate: DateTime.now(),
        records: [
          SessionRecord(
            memberId: 'm1',
            attendee: 'Alice Updated',
            status: AttendanceStatus.present,
            recordedAt: DateTime.now(),
            recordedBy: 'user',
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'user',
      );

      final roster = SessionRoster(session, baseMembers);

      expect(roster.displayMembersMap.containsKey('m1'), true);
      expect(roster.displayMembersMap['m1']?.displayName, 'Alice Updated');
      expect(roster.getStatus(roster.displayMembersMap['m1']!), AttendanceStatus.present);
    });

    test('should handle visitors correctly', () {
      final session = Session(
        id: 's1',
        title: 'Session 1',
        sessionDate: DateTime.now(),
        records: [
          SessionRecord(
            memberId: null,
            attendee: 'Charlie (Visitor)',
            status: AttendanceStatus.present,
            recordedAt: DateTime.now(),
            recordedBy: 'user',
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'user',
      );

      final roster = SessionRoster(session, baseMembers);

      final visitor = roster.displayMembersMap['visitor_Charlie (Visitor)'];
      expect(visitor, isNotNull);
      expect(visitor?.isVisitor, true);
      expect(roster.getStatus(visitor!), AttendanceStatus.present);
    });

    test('should respect excludedMemberIds', () {
      final session = Session(
        id: 's1',
        title: 'Session 1',
        sessionDate: DateTime.now(),
        records: [],
        excludedMemberIds: ['m1'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'user',
      );

      final roster = SessionRoster(session, baseMembers);

      expect(roster.displayMembersMap.containsKey('m1'), false);
      expect(roster.displayMembersMap.containsKey('m2'), true);
    });
  });
}
