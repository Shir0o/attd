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

    test('keeps two id-less base members (Guest Marks) distinct', () {
      SessionRecord guestMark(String name) => SessionRecord(
            memberId: null,
            attendee: name,
            status: AttendanceStatus.present,
            recordedAt: DateTime.now(),
            recordedBy: 'user',
          );
      final session = Session(
        id: 's1',
        title: 'Session 1',
        sessionDate: DateTime.now(),
        records: [guestMark('Dana'), guestMark('Eli')],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'user',
      );

      final roster = SessionRoster(session, [
        ...baseMembers,
        Member(id: '', displayName: 'Dana', isVisitor: true),
        Member(id: '', displayName: 'Eli', isVisitor: true),
      ]);

      expect(roster.displayMembersMap.containsKey(''), false);
      final dana = roster.displayMembersMap['visitor_Dana'];
      final eli = roster.displayMembersMap['visitor_Eli'];
      expect(dana?.id, 'visitor_Dana');
      expect(eli?.id, 'visitor_Eli');
      // Still Guest Marks: a visitor, so writes keep a null member ID.
      expect(dana?.isVisitor, true);
      expect(eli?.isVisitor, true);
      expect(roster.getStatus(dana!), AttendanceStatus.present);
      expect(roster.getStatus(eli!), AttendanceStatus.present);
      expect(roster.displayMembersMap.length, 4);
    });
  });

  group('memberLastName', () {
    test('extracts the last token of multi-token names', () {
      expect(memberLastName('John Doe'), 'Doe');
      expect(memberLastName('Mary Jane Watson'), 'Watson');
    });

    test('returns the single name when only one token exists', () {
      expect(memberLastName('Cher'), 'Cher');
    });

    test('handles leading, trailing, and multiple spaces', () {
      expect(memberLastName('  Alice   Wonderland  '), 'Wonderland');
    });

    test('returns empty string for blank names', () {
      expect(memberLastName(''), '');
      expect(memberLastName('   '), '');
    });
  });

  group('memberGivenName', () {
    test('extracts all tokens except the last of multi-token names', () {
      expect(memberGivenName('John Doe'), 'John');
      expect(memberGivenName('Mary Jane Watson'), 'Mary Jane');
    });

    test('returns the single name when only one token exists', () {
      expect(memberGivenName('Cher'), 'Cher');
    });

    test('handles leading, trailing, and multiple spaces', () {
      expect(memberGivenName('  Alice   Wonderland  '), 'Alice');
      expect(memberGivenName('  Mary   Jane   Watson  '), 'Mary Jane');
    });

    test('returns empty string for blank names', () {
      expect(memberGivenName(''), '');
      expect(memberGivenName('   '), '');
    });
  });
}
