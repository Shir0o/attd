import 'package:attendance_tracker/features/attendance/domain/active_roster_index.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:flutter_test/flutter_test.dart';

Member _m(String id, String name, {bool isVisitor = false}) =>
    Member(id: id, displayName: name, isVisitor: isVisitor);

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
      expect(index.givenNameFor(john1), 'John');
    });

    test('names a member the index was not built with', () {
      final index = ActiveRosterIndex(members: [_m('m1', 'Bob Jones')]);
      final outsideMember = Member(id: 'outside', displayName: 'John Doe');

      expect(index.hasDistinctSurname(outsideMember), isTrue);
      expect(index.surnameFor(outsideMember), 'Doe');
      expect(index.givenNameFor(outsideMember), 'John');
    });

    test('indexes visitors with a visitor ID correctly', () {
      final visitor = _m('visitor_Dana', 'Dana (Visitor)', isVisitor: true);
      final index = ActiveRosterIndex(members: [visitor]);

      expect(index.hasDistinctSurname(visitor), isTrue);
      expect(index.surnameFor(visitor), '(Visitor)');
      expect(index.displayNameFor(visitor), 'Dana');
    });
  });

  group('ActiveRosterIndex - Match Ranking', () {
    test('ranks a leading match 0, a word prefix 1, and a substring 2', () {
      expect(ActiveRosterIndex.calculateMatchRankLowercased('nguyen an', 'ngu'), 0);
      expect(ActiveRosterIndex.calculateMatchRankLowercased('an nguyen', 'ngu'), 1);
      expect(ActiveRosterIndex.calculateMatchRankLowercased('jean-luc picard', 'pic'), 1);
      expect(ActiveRosterIndex.calculateMatchRankLowercased("sarah o'connor", 'con'), 1);
      expect(ActiveRosterIndex.calculateMatchRankLowercased('bangui sese', 'ngu'), 2);
      expect(ActiveRosterIndex.calculateMatchRankLowercased('an nguyen', 'zzz'), isNull);
      expect(ActiveRosterIndex.calculateMatchRankLowercased('an nguyen', ''), isNull);
    });

    test('matchesLowercased is true when the query appears, and for a blank query', () {
      final index = ActiveRosterIndex(members: const []);
      expect(index.matchesLowercased('an nguyen', 'ngu'), isTrue);
      expect(index.matchesLowercased('an nguyen', 'zzz'), isFalse);
      expect(index.matchesLowercased('an nguyen', ''), isTrue);
      expect(index.matchesLowercased('an nguyen', '   '), isTrue);
    });

    test('matchesLowercased tolerates an untrimmed, mixed-case query', () {
      final index = ActiveRosterIndex(members: const []);
      expect(index.matchesLowercased('an nguyen', '  NGU '), isTrue);
    });
  });
}
