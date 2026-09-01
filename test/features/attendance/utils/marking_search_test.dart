import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/utils/member_default_resolver.dart';
import 'package:attendance_tracker/features/attendance/utils/session_roster_utils.dart';
import 'package:flutter_test/flutter_test.dart';

Member m(String id, String name) => Member(id: id, displayName: name);

Session sessionOf(Map<String, bool> presentByMemberId, {int day = 1}) {
  final at = DateTime(2026, 1, day);
  return Session(
    id: 's$day',
    title: 'S',
    sessionDate: at,
    createdAt: at,
    updatedAt: at,
    createdBy: 'User',
    records: [
      for (final e in presentByMemberId.entries)
        SessionRecord(
          memberId: e.key,
          attendee: e.key,
          status: e.value ? AttendanceStatus.present : AttendanceStatus.absent,
          recordedAt: at,
          recordedBy: 'User',
        ),
    ],
  );
}

void main() {
  group('attendanceRate', () {
    test('returns null below the minimum sample count', () {
      final sessions = [
        sessionOf({'a': true}, day: 1),
        sessionOf({'a': true}, day: 2),
      ];
      expect(attendanceRate('a', sessions), isNull);
    });

    test('returns null for a member with no history at all', () {
      expect(attendanceRate('ghost', [sessionOf({'a': true})]), isNull);
    });

    test('is the share of recorded sessions the member was present for', () {
      final sessions = [
        sessionOf({'a': true}, day: 1),
        sessionOf({'a': true}, day: 2),
        sessionOf({'a': true}, day: 3),
        sessionOf({'a': false}, day: 4),
      ];
      expect(attendanceRate('a', sessions), closeTo(0.75, 1e-9));
    });

    test('only consults the most recent window of sessions', () {
      final sessions = [
        for (var d = 1; d <= kPatternWindow; d++)
          sessionOf({'a': true}, day: d),
        // Older than the window — must not drag the rate down.
        for (var d = kPatternWindow + 1; d <= kPatternWindow + 4; d++)
          sessionOf({'a': false}, day: d),
      ];
      expect(attendanceRate('a', sessions), 1.0);
    });
  });

  group('rankByLikelihood', () {
    test('orders by descending recent attendance rate', () {
      final members = [m('low', 'Low'), m('high', 'High'), m('mid', 'Mid')];
      final sessions = [
        sessionOf({'low': false, 'mid': true, 'high': true}, day: 1),
        sessionOf({'low': false, 'mid': false, 'high': true}, day: 2),
        sessionOf({'low': false, 'mid': true, 'high': true}, day: 3),
      ];
      expect(
        rankByLikelihood(members, sessions).map((x) => x.id),
        ['high', 'mid', 'low'],
      );
    });

    test('sorts members with too little history after every ranked one', () {
      final members = [m('new', 'Aaron New'), m('known', 'Zoe Known')];
      final sessions = [
        sessionOf({'known': false}, day: 1),
        sessionOf({'known': false}, day: 2),
        sessionOf({'known': false}, day: 3),
      ];
      // Zoe never attends, but she is still ranked; Aaron has no history.
      expect(
        rankByLikelihood(members, sessions).map((x) => x.id),
        ['known', 'new'],
      );
    });

    test('breaks ties alphabetically by display name', () {
      final members = [m('c', 'Carol'), m('a', 'Alice'), m('b', 'Bob')];
      final sessions = [
        sessionOf({'a': true, 'b': true, 'c': true}, day: 1),
        sessionOf({'a': true, 'b': true, 'c': true}, day: 2),
        sessionOf({'a': true, 'b': true, 'c': true}, day: 3),
      ];
      expect(
        rankByLikelihood(members, sessions).map((x) => x.displayName),
        ['Alice', 'Bob', 'Carol'],
      );
    });

    test('falls back to alphabetical order with no history at all', () {
      final members = [m('c', 'Carol'), m('a', 'Alice')];
      expect(
        rankByLikelihood(members, const []).map((x) => x.displayName),
        ['Alice', 'Carol'],
      );
    });

    test('does not mutate the list it was given', () {
      final members = [m('c', 'Carol'), m('a', 'Alice')];
      rankByLikelihood(members, const []);
      expect(members.map((x) => x.id), ['c', 'a']);
    });
  });

  group('matchRank', () {
    test('ranks a leading prefix best', () {
      expect(matchRank('Nguyen An', 'ngu'), 0);
    });

    test('ranks a later word prefix second', () {
      expect(matchRank('An Nguyen', 'ngu'), 1);
    });

    test('ranks a mid-word substring last', () {
      expect(matchRank('Bangui Sese', 'ngu'), 2);
    });

    test('returns null when the name does not contain the query', () {
      expect(matchRank('An Nguyen', 'zzz'), isNull);
    });

    test('returns null for a blank query', () {
      expect(matchRank('An Nguyen', '   '), isNull);
    });

    test('ignores case and surrounding whitespace in the query', () {
      expect(matchRank('An Nguyen', '  NGU  '), 1);
    });
  });

  group('nameInitials', () {
    test('takes the first letter of the first and last token', () {
      expect(nameInitials('An Nguyen'), (first: 'A', last: 'N'));
    });

    test('uses the final token for names with a middle name', () {
      expect(nameInitials('Mary Jane Watson'), (first: 'M', last: 'W'));
    });

    test('repeats the single letter for a one-word name', () {
      expect(nameInitials('Prince'), (first: 'P', last: 'P'));
    });

    test('collapses extra whitespace', () {
      expect(nameInitials('  An   Nguyen  '), (first: 'A', last: 'N'));
    });

    test('yields empty initials for a blank name', () {
      expect(nameInitials('   '), (first: '', last: ''));
    });

    test('upper-cases the letters', () {
      expect(nameInitials('an nguyen'), (first: 'A', last: 'N'));
    });
  });

  group('initialsIndex', () {
    test('maps each first initial to the surname initials under it', () {
      final index = initialsIndex([
        m('1', 'Nadia Gruber'),
        m('2', 'Nathan Gyamfi'),
        m('3', 'Nina Okafor'),
        m('4', 'Duc Nguyen'),
      ]);
      expect(index.keys.toSet(), {'N', 'D'});
      expect(index['N'], {'G', 'O'});
      expect(index['D'], {'N'});
    });

    test('skips members with a blank display name', () {
      final index = initialsIndex([m('1', '   '), m('2', 'An Nguyen')]);
      expect(index.keys, ['A']);
    });

    test('is empty for an empty roster', () {
      expect(initialsIndex(const []), isEmpty);
    });
  });

  group('rankedSearch', () {
    List<SearchEntry> entries(List<(String, String, String?)> raw) => [
          for (final (id, name, family) in raw)
            (member: m(id, name), familyName: family),
        ];

    test('returns nothing for a blank query', () {
      expect(rankedSearch(entries([('a', 'An Nguyen', null)]), '  '), isEmpty);
    });

    test('orders a leading prefix ahead of a later word prefix', () {
      final out = rankedSearch(
        entries([('later', 'An Nguyen', null), ('lead', 'Nguyen An', null)]),
        'ngu',
      );
      expect(out.map((e) => e.member.id), ['lead', 'later']);
    });

    test('puts every name match ahead of a family-only match', () {
      final out = rankedSearch(
        entries([
          ('familyonly', 'Zed Alvarez', 'Nguyen'),
          ('nameonly', 'Bao Nguyenson', null),
        ]),
        'nguyen',
      );
      expect(out.map((e) => e.member.id), ['nameonly', 'familyonly']);
    });

    test('excludes entries that match neither name nor family', () {
      final out = rankedSearch(
        entries([('a', 'An Nguyen', null), ('b', 'Sam Okafor', 'Okafor')]),
        'ngu',
      );
      expect(out.map((e) => e.member.id), ['a']);
    });

    test('breaks ties on the supplied priority, lowest first', () {
      final out = rankedSearch(
        entries([('slow', 'Ngu Beta', null), ('fast', 'Ngu Alpha', null)]),
        'ngu',
        priority: {'fast': 0, 'slow': 1},
      );
      expect(out.map((e) => e.member.id), ['fast', 'slow']);
    });

    test('sorts entries missing from the priority map last', () {
      final out = rankedSearch(
        entries([('unranked', 'Ngu Aaa', null), ('ranked', 'Ngu Zzz', null)]),
        'ngu',
        priority: {'ranked': 3},
      );
      expect(out.map((e) => e.member.id), ['ranked', 'unranked']);
    });

    test('falls back to display name when priorities are equal', () {
      final out = rankedSearch(
        entries([('b', 'Ngu Beta', null), ('a', 'Ngu Alpha', null)]),
        'ngu',
      );
      expect(out.map((e) => e.member.displayName), ['Ngu Alpha', 'Ngu Beta']);
    });
  });
}
