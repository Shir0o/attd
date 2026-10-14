import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/domain/active_roster_index.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:flutter_test/flutter_test.dart';

Member _m(String id, String name, {bool isVisitor = false}) =>
    Member(id: id, displayName: name, isVisitor: isVisitor);

Session _sessionOf(Map<String, bool> presentByMemberId, {int day = 1}) {
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
  group('ActiveRosterIndex - Name Tokenizer and Attendee Surname Rules', () {
    test('tokenizes names on whitespace and handles extra whitespace', () {
      expect(
        ActiveRosterIndex.tokenizeName('  Mary   Jane   Watson  '),
        ['Mary', 'Jane', 'Watson'],
      );
      expect(ActiveRosterIndex.tokenizeName(''), isEmpty);
      expect(ActiveRosterIndex.tokenizeName('   '), isEmpty);
      expect(ActiveRosterIndex.tokenizeName('Cher'), ['Cher']);
    });

    test('extracts attendee surname as last whitespace-delimited token', () {
      expect(ActiveRosterIndex.extractLastName('John Doe'), 'Doe');
      expect(ActiveRosterIndex.extractLastName('Mary Jane Watson'), 'Watson');
      expect(ActiveRosterIndex.extractLastName('Cher'), 'Cher');
      expect(ActiveRosterIndex.extractLastName('Jean-Luc Picard'), 'Picard');
      expect(ActiveRosterIndex.extractLastName('Sarah Parker-Bowles'), 'Parker-Bowles');
      expect(ActiveRosterIndex.extractLastName(''), '');
      expect(ActiveRosterIndex.extractLastName('   '), '');
    });

    test('extracts given name as all tokens except last, or full name for single-token', () {
      expect(ActiveRosterIndex.extractGivenName('John Doe'), 'John');
      expect(ActiveRosterIndex.extractGivenName('Mary Jane Watson'), 'Mary Jane');
      expect(ActiveRosterIndex.extractGivenName('Cher'), 'Cher');
      expect(ActiveRosterIndex.extractGivenName('Jean-Luc Picard'), 'Jean-Luc');
      expect(ActiveRosterIndex.extractGivenName(''), '');
      expect(ActiveRosterIndex.extractGivenName('   '), '');
    });

    test('extracts uppercase initials for first and last name tokens', () {
      expect(ActiveRosterIndex.extractInitials('an nguyen'), (first: 'A', last: 'N'));
      expect(ActiveRosterIndex.extractInitials('Mary Jane Watson'), (first: 'M', last: 'W'));
      expect(ActiveRosterIndex.extractInitials('Prince'), (first: 'P', last: 'P'));
      expect(ActiveRosterIndex.extractInitials('  An   Nguyen  '), (first: 'A', last: 'N'));
      expect(ActiveRosterIndex.extractInitials(''), (first: '', last: ''));
      expect(ActiveRosterIndex.extractInitials('   '), (first: '', last: ''));
    });

    test('identifies distinct surname correctly', () {
      final index = ActiveRosterIndex(
        members: [
          _m('1', 'John Doe'),
          _m('2', 'Cher'),
          _m('3', 'Mary Jane Watson'),
          _m('4', '   '),
        ],
      );

      expect(index.hasDistinctSurname(_m('1', 'John Doe')), isTrue);
      expect(index.hasDistinctSurname(_m('2', 'Cher')), isFalse);
      expect(index.hasDistinctSurname(_m('3', 'Mary Jane Watson')), isTrue);
      expect(index.hasDistinctSurname(_m('4', '   ')), isFalse);
    });

    test('displayNameFor returns given name when distinct surname exists, and full name for single-token', () {
      final index = ActiveRosterIndex(
        members: [
          _m('1', 'John Doe'),
          _m('2', 'Cher'),
          _m('3', 'Mary Jane Watson'),
        ],
      );

      expect(index.displayNameFor(_m('1', 'John Doe')), 'John');
      expect(index.displayNameFor(_m('2', 'Cher')), 'Cher');
      expect(index.displayNameFor(_m('3', 'Mary Jane Watson')), 'Mary Jane');
    });

    test('disambiguates identical given names via Attendee Surname', () {
      final john1 = _m('j1', 'John Smith');
      final john2 = _m('j2', 'John Doe');
      final index = ActiveRosterIndex(members: [john1, john2]);

      expect(index.displayNameFor(john1), 'John');
      expect(index.displayNameFor(john2), 'John');
      expect(index.surnameFor(john1), 'Smith');
      expect(index.surnameFor(john2), 'Doe');
    });
  });

  group('ActiveRosterIndex - Likelihood Ordering (likelyHere)', () {
    test('orders by recent attendance rate descending, breaking ties alphabetically', () {
      final low = _m('low', 'Low Attendee');
      final high = _m('high', 'High Attendee');
      final mid = _m('mid', 'Mid Attendee');
      final sessions = [
        _sessionOf({'low': false, 'mid': true, 'high': true}, day: 1),
        _sessionOf({'low': false, 'mid': false, 'high': true}, day: 2),
        _sessionOf({'low': false, 'mid': true, 'high': true}, day: 3),
      ];

      final index = ActiveRosterIndex(
        members: [low, high, mid],
        recentSessions: sessions,
      );

      expect(index.likelyHere().map((m) => m.id), ['high', 'mid', 'low']);
      expect(index.rateFor(high), closeTo(1.0, 1e-9));
      expect(index.rateFor(mid), closeTo(2 / 3, 1e-9));
      expect(index.rateFor(low), closeTo(0.0, 1e-9));
    });

    test('places members with insufficient history after ranked members', () {
      final newMember = _m('new', 'Aaron New');
      final known = _m('known', 'Zoe Known');
      final sessions = [
        _sessionOf({'known': false}, day: 1),
        _sessionOf({'known': false}, day: 2),
        _sessionOf({'known': false}, day: 3),
      ];

      final index = ActiveRosterIndex(
        members: [newMember, known],
        recentSessions: sessions,
      );

      expect(index.likelyHere().map((m) => m.id), ['known', 'new']);
      expect(index.rateFor(known), 0.0);
      expect(index.rateFor(newMember), isNull);
    });

    test('falls back to alphabetical order without history', () {
      final c = _m('c', 'Carol');
      final a = _m('a', 'Alice');
      final b = _m('b', 'Bob');

      final index = ActiveRosterIndex(members: [c, a, b]);
      expect(index.likelyHere().map((m) => m.displayName), ['Alice', 'Bob', 'Carol']);
    });

    test('does not mutate input members list', () {
      final members = [_m('c', 'Carol'), _m('a', 'Alice')];
      ActiveRosterIndex(members: members);
      expect(members.map((m) => m.id), ['c', 'a']);
    });
  });

  group('ActiveRosterIndex - Initials Index', () {
    test('builds full initials map on initialization', () {
      final index = ActiveRosterIndex(
        members: [
          _m('1', 'Nadia Gruber'),
          _m('2', 'Nathan Gyamfi'),
          _m('3', 'Nina Okafor'),
          _m('4', 'Duc Nguyen'),
          _m('5', '   '),
        ],
      );

      final fullIndex = index.initialsIndex();
      expect(fullIndex.keys.toSet(), {'N', 'D'});
      expect(fullIndex['N'], {'G', 'O'});
      expect(fullIndex['D'], {'N'});
    });

    test('computes initials map for an unmarked subset using precomputed initials', () {
      final m1 = _m('1', 'Nadia Gruber');
      final m2 = _m('2', 'Nathan Gyamfi');
      final m3 = _m('3', 'Nina Okafor');
      final m4 = _m('4', 'Duc Nguyen');

      final index = ActiveRosterIndex(members: [m1, m2, m3, m4]);

      // Subset with only m1 and m4 unmarked
      final subsetIndex = index.initialsIndex([m1, m4]);
      expect(subsetIndex.keys.toSet(), {'N', 'D'});
      expect(subsetIndex['N'], {'G'});
      expect(subsetIndex['D'], {'N'});
    });

    test('retrieves members matching initials', () {
      final m1 = _m('m1', 'Nadia Gruber');
      final m2 = _m('m2', 'Nathan Gyamfi');
      final m3 = _m('m3', 'Nina Okafor');

      final index = ActiveRosterIndex(members: [m1, m2, m3]);
      expect(index.membersWithInitials('N').map((m) => m.id), ['m1', 'm2', 'm3']);
      expect(index.membersWithInitials('N', last: 'G').map((m) => m.id), ['m1', 'm2']);
      expect(index.membersWithInitials('N', last: 'O').map((m) => m.id), ['m3']);
      expect(index.membersWithInitials('Z'), isEmpty);
    });
  });

  group('ActiveRosterIndex - Search and Match Ranking', () {
    test('matchRank ranks exact prefix best (0), word prefix (1), substring (2)', () {
      expect(ActiveRosterIndex.calculateMatchRank('Nguyen An', 'ngu'), 0);
      expect(ActiveRosterIndex.calculateMatchRank('An Nguyen', 'ngu'), 1);
      expect(ActiveRosterIndex.calculateMatchRank('Jean-Luc Picard', 'pic'), 1);
      expect(ActiveRosterIndex.calculateMatchRank("Sarah O'Connor", 'con'), 1);
      expect(ActiveRosterIndex.calculateMatchRank('Bangui Sese', 'ngu'), 2);
      expect(ActiveRosterIndex.calculateMatchRank('An Nguyen', 'zzz'), isNull);
      expect(ActiveRosterIndex.calculateMatchRank('An Nguyen', '   '), isNull);
    });

    test('matches returns true if matchRank is non-null', () {
      final index = ActiveRosterIndex(members: const []);
      expect(index.matches('An Nguyen', 'ngu'), isTrue);
      expect(index.matches('An Nguyen', 'zzz'), isFalse);
      expect(index.matches('An Nguyen', ''), isTrue);
      expect(index.matches('An Nguyen', '   '), isTrue);
    });

    test('search returns ranked results by match tier and likelihood priority', () {
      final duc = _m('duc', 'Duc Nguyen');
      final an = _m('an', 'An Nguyen');
      final bao = _m('bao', 'Bao Nguyen');
      final zed = _m('zed', 'Zed Alvarez');

      final family = Family(
        id: 'f1',
        displayName: 'Nguyens',
        members: [zed], // Family-only match for query 'nguyen'
      );

      final sessions = [
        _sessionOf({'duc': true, 'bao': true}, day: 1),
        _sessionOf({'duc': true, 'bao': false}, day: 2),
        _sessionOf({'duc': true, 'bao': true}, day: 3),
      ];

      final index = ActiveRosterIndex(
        members: [duc, an, bao, zed],
        families: [family],
        recentSessions: sessions,
      );

      // Blank query returns empty list
      expect(index.search('   '), isEmpty);

      // Leading prefix beats later word prefix
      final resLead = index.search('ngu');
      // All Nguyens match 'ngu' as word prefix; Duc is most likely, then Bao, then An.
      // Zed matches family name 'Nguyens' which ranks worse (+3) than display name.
      expect(resLead.map((e) => e.member.id), ['duc', 'bao', 'an', 'zed']);

      // Exact prefix vs word prefix:
      final indexPrefix = ActiveRosterIndex(
        members: [_m('lead', 'Nguyen An'), _m('later', 'An Nguyen')],
      );
      final resPrefix = indexPrefix.search('ngu');
      expect(resPrefix.map((e) => e.member.id), ['lead', 'later']);
    });

    test('isUnambiguous returns true when single result or top hit is strictly higher rank', () {
      final index = ActiveRosterIndex(
        members: [_m('lead', 'Nguyen An'), _m('later', 'An Nguyen')],
      );
      final results = index.search('ngu');
      // 'lead' is rank 0, 'later' is rank 1 -> unambiguous!
      expect(index.isUnambiguous('ngu', results), isTrue);

      final indexTie = ActiveRosterIndex(
        members: [_m('a', 'An Nguyen'), _m('b', 'Bao Nguyen')],
      );
      final tieResults = indexTie.search('ngu');
      // Both are rank 1 -> ambiguous!
      expect(indexTie.isUnambiguous('ngu', tieResults), isFalse);
    });
  });

  group('ActiveRosterIndex - Household Grouping (groupedByFamily)', () {
    test('returns all non-empty families without query', () {
      final m1 = _m('1', 'Alice Smith');
      final m2 = _m('2', 'Bob Jones');
      final f1 = Family(id: 'f1', displayName: 'Smiths', members: [m1]);
      final f2 = Family(id: 'f2', displayName: 'Joneses', members: [m2]);
      final fEmpty = Family(id: 'f3', displayName: 'Empty', members: []);

      final index = ActiveRosterIndex(
        members: [m1, m2],
        families: [f1, f2, fEmpty],
      );

      expect(index.groupedByFamily().map((f) => f.id), ['f1', 'f2']);
    });

    test('searches families by family display name or member display name', () {
      final m1 = _m('1', 'Alice Smith');
      final m2 = _m('2', 'Duc Nguyen');
      final fSmith = Family(id: 'f1', displayName: 'Smiths', members: [m1]);
      final fNguyen = Family(id: 'f2', displayName: 'Nguyens', members: [m2]);

      final index = ActiveRosterIndex(
        members: [m1, m2],
        families: [fSmith, fNguyen],
      );

      // Match via family name
      expect(index.groupedByFamily(query: 'smi').map((f) => f.id), ['f1']);
      // Match via member name inside family
      expect(index.groupedByFamily(query: 'duc').map((f) => f.id), ['f2']);
      // Respects limit
      expect(index.groupedByFamily(query: 's', limit: 1).length, 1);
    });
  });

  group('ActiveRosterIndex - Subtitle Formatting', () {
    test('formats subtitle using family name, rate, and surname fallback', () {
      final m1 = _m('1', 'Alice Smith');
      final m2 = _m('2', 'Bob Doe');
      final m3 = _m('3', 'Cher');
      final f1 = Family(id: 'f1', displayName: 'Smith Family', members: [m1]);
      final fSingleton = Family(id: 'f2', displayName: 'Doe', isAutoSingleton: true, members: [m2]);

      final sessions = [
        _sessionOf({'1': true}, day: 1),
        _sessionOf({'1': true}, day: 2),
        _sessionOf({'1': true}, day: 3),
      ];

      final index = ActiveRosterIndex(
        members: [m1, m2, m3],
        families: [f1, fSingleton],
        recentSessions: sessions,
      );

      // Has family name and rate
      expect(index.subtitleFor(m1), 'Smith Family · 100% recently');
      // Auto-singleton family ignored -> falls back to attendee surname
      expect(index.subtitleFor(m2), 'Doe');
      // Single-token name with no family
      expect(index.subtitleFor(m3), 'Cher');
    });

    test('falls back to Loner for blank names with no family', () {
      final blankMember = _m('b', '   ');
      final index = ActiveRosterIndex(members: [blankMember]);
      expect(index.subtitleFor(blankMember), 'Loner');
    });
  });

  group('ActiveRosterIndex - Unlisted Guests / Visitors', () {
    test('indexes visitors with null or visitor ID correctly', () {
      final visitor = _m('visitor_Dana', 'Dana (Visitor)', isVisitor: true);
      final index = ActiveRosterIndex(members: [visitor]);

      expect(index.likelyHere().first.displayName, 'Dana (Visitor)');
      expect(index.hasDistinctSurname(visitor), isTrue);
      expect(index.surnameFor(visitor), '(Visitor)');
      expect(index.displayNameFor(visitor), 'Dana');
      expect(index.search('dana').first.member.id, 'visitor_Dana');
    });
  });

  group('ActiveRosterIndex - Edge Cases & Auxiliary Methods', () {
    test('exposes searchEntries and supports search with limit and tie breaks', () {
      final m1 = _m('m1', 'Alex Smith');
      final m2 = _m('m2', 'Bob Smith');
      final index = ActiveRosterIndex(members: [m2, m1]);

      expect(index.searchEntries.length, 2);
      expect(index.matchRank('Alex Smith', 'smith'), 1);

      // Search with limit
      final limited = index.search('smith', limit: 1);
      expect(limited.length, 1);

      // Tie break by display name when priorities are equal
      final all = index.search('smith');
      expect(all.map((e) => e.member.displayName).toList(), ['Alex Smith', 'Bob Smith']);
    });

    test('groupedByFamily supports limits and tie-breaks', () {
      final m1 = _m('m1', 'Member 1');
      final m2 = _m('m2', 'Member 2');
      final f1 = Family(id: 'f1', displayName: 'Beta Family', members: [m1]);
      final f2 = Family(id: 'f2', displayName: 'Alpha Family', members: [m2]);
      final index = ActiveRosterIndex(
        members: [m1, m2],
        families: [f1, f2],
      );

      // Without query with limit
      expect(index.groupedByFamily(limit: 1).length, 1);

      // With query tie-breaking by family display name alphabetically
      final matched = index.groupedByFamily(query: 'Family');
      expect(matched.map((f) => f.displayName).toList(), ['Alpha Family', 'Beta Family']);

      // With query and limit
      expect(index.groupedByFamily(query: 'Family', limit: 1).length, 1);
    });

    test('handles unindexed member in hasDistinctSurname and likelyHere tie-break', () {
      final m1 = _m('m1', 'Bob Jones');
      final m2 = _m('m2', 'Alice Jones');
      final session = _sessionOf({'m1': true, 'm2': true});
      final index = ActiveRosterIndex(members: [m1, m2], recentSessions: [session]);

      // Both have 100% rate, so they tie-break alphabetically
      expect(index.likelyHere().map((m) => m.displayName).toList(), ['Alice Jones', 'Bob Jones']);

      // Unindexed member passed to hasDistinctSurname
      final outsideMember = Member(id: 'outside', displayName: 'John Doe');
      expect(index.hasDistinctSurname(outsideMember), isTrue);
    });
  });
}

