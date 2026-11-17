import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/checkon/domain/check_on.dart';
import 'package:attendance_tracker/features/checkon/domain/check_on_board.dart';
import 'package:attendance_tracker/features/checkon/domain/check_on_follow_up.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';

final _start = DateTime(2026, 1, 7);
final _ann = Member(id: 'm1', displayName: 'Ann');
final _bob = Member(id: 'm2', displayName: 'Bob');

Event _event({String id = 'e1', String title = 'Study'}) => Event(
      id: id,
      title: title,
      time: const TimeOfDay(hour: 19, minute: 0),
      frequency: 'Weekly',
      createdAt: DateTime(2026, 1, 1),
    );

/// One session per character, oldest first: `x` present, `.` absent.
List<Session> _sessions(
  Map<Member, String> patterns, {
  String eventId = 'e1',
  String title = 'Study',
}) {
  final n = patterns.values.first.length;
  return [
    for (var i = 0; i < n; i++)
      Session(
        id: '$eventId-s$i',
        eventId: eventId,
        title: title,
        sessionDate: _start.add(Duration(days: 7 * i)),
        records: [
          for (final e in patterns.entries)
            SessionRecord(
              memberId: e.key.id,
              attendee: e.key.displayName,
              status: e.value[i] == 'x'
                  ? AttendanceStatus.present
                  : AttendanceStatus.absent,
              recordedAt: _start,
              recordedBy: 'user',
            ),
        ],
        createdAt: _start,
        updatedAt: _start,
        createdBy: 'user',
      ),
  ];
}

CheckOnBoard _board(
  List<Event> events,
  List<Session> sessions, [
  List<Member>? members,
]) =>
    CheckOnBoard.compute(
      events: events,
      members: members ?? [_ann, _bob],
      sessions: sessions,
    );

void main() {
  group('Event storage', () {
    test('an event with no answers writes no keys', () {
      final json = _event().toJson();
      expect(json.containsKey('checkOnFollowUps'), isFalse);
      expect(json.containsKey('checkOnStopFlagging'), isFalse);
    });

    test('old data without the keys loads with empty answers', () {
      final event = Event.fromJson(_event().toJson());
      expect(event.checkOnFollowUps, isEmpty);
      expect(event.checkOnStopFlagging, isEmpty);
    });

    test('ticks and stop-flagging round-trip as discrete keys', () {
      final event = _event().copyWith(
        checkOnFollowUps: {
          'm1': CheckOnFollowUp(
            flag: CheckOnFlag.goneQuiet.name,
            lastPresent: DateTime(2026, 3, 4),
          ),
        },
        checkOnStopFlagging: {'m3', 'm2'},
      );
      final json = event.toJson();
      expect(json['checkOnFollowUps'], {
        'm1': {'flag': 'goneQuiet', 'lastPresent': '2026-03-04'},
      });
      expect(json['checkOnStopFlagging'], ['m2', 'm3']);

      final back = Event.fromJson(json);
      expect(back.checkOnFollowUps['m1'], event.checkOnFollowUps['m1']);
      expect(back.checkOnStopFlagging, {'m2', 'm3'});
    });

    test('malformed entries are skipped without failing the load', () {
      final json = _event().toJson()
        ..['checkOnFollowUps'] = {
          'bad1': 'nope',
          'bad2': {'flag': 1, 'lastPresent': '2026-01-01'},
          'bad3': {'flag': 'goneQuiet', 'lastPresent': 'not a date'},
          'ok': {'flag': 'goneQuiet', 'lastPresent': '2026-01-01'},
        }
        ..['checkOnStopFlagging'] = ['m1', 7];
      final event = Event.fromJson(json);
      expect(event.checkOnFollowUps.keys, ['ok']);
      expect(event.checkOnStopFlagging, {'m1'});
    });

    test('copyWith keeps answers unless replaced', () {
      final ticked = _event().copyWith(checkOnStopFlagging: {'m1'});
      expect(ticked.copyWith(title: 'x').checkOnStopFlagging, {'m1'});
      expect(ticked.copyWith(checkOnStopFlagging: {}).checkOnStopFlagging,
          isEmpty);
    });

    test('a follow-up equals another on the same day only', () {
      final a = CheckOnFollowUp(flag: 'goneQuiet', lastPresent: DateTime(2026));
      final b = CheckOnFollowUp(
        flag: 'goneQuiet',
        lastPresent: DateTime(2026, 1, 1, 18),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(CheckOnFollowUp(
            flag: 'goneQuiet', lastPresent: DateTime(2026, 1, 2))),
      );
      expect(
          a,
          isNot(CheckOnFollowUp(
              flag: 'suddenDrop', lastPresent: DateTime(2026))));
      expect(a == Object(), isFalse);
    });
  });

  group('CheckOnBoard', () {
    test('lists flagged people, most serious first', () {
      final board = _board(
        [_event()],
        _sessions({_ann: 'xx.....', _bob: 'xxxx...'}),
      );
      expect(board.entries.map((e) => e.displayName), ['Ann', 'Bob']);
      expect(board.toCheck.map((p) => p.displayName), ['Ann', 'Bob']);
    });

    test('skips deleted events', () {
      final board = _board(
        [_event().copyWith(deletedAt: DateTime(2026, 2, 1))],
        _sessions({_ann: 'xx....'}),
      );
      expect(board.entries, isEmpty);
    });

    test('skips events handed off by someone else', () {
      final handedOff = _event().copyWith(handoffEventId: 'ev-1');
      final sessions = _sessions({_ann: 'xx.....', _bob: 'xxxx...'});

      expect(_board([handedOff], sessions).entries, isEmpty);

      // The helper's own event is unaffected alongside it.
      final own = _event(id: 'own', title: 'Own');
      final mixed = _board(
        [handedOff, own],
        [..._sessions({_ann: 'xx.....'}, eventId: 'own', title: 'Own')],
      );
      expect(mixed.entries.map((e) => e.eventId).toSet(), {'own'});
    });

    test('stop flagging hides the person on that event only', () {
      final sessions = [
        ..._sessions({_ann: 'xx....'}),
        ..._sessions({_ann: 'xx....'}, eventId: 'e2', title: 'Prayer'),
      ];
      final board = _board(
        [
          _event().copyWith(checkOnStopFlagging: {'m1'}),
          _event(id: 'e2', title: 'Prayer'),
        ],
        sessions,
        [_ann],
      );
      expect(board.entries.map((e) => e.eventTitle), ['Prayer']);
    });

    test('a tick hides the person from toCheck but keeps them in people', () {
      final sessions = _sessions({_ann: 'xx....'});
      final plain = _board([_event()], sessions);
      final entry = plain.entries.single;
      final ticked = _board(
        [
          _event().withFollowUps([entry])
        ],
        sessions,
      );
      expect(ticked.toCheck, isEmpty);
      final people = ticked.people();
      expect(people.single.displayName, 'Ann');
      expect(ticked.isPersonFollowedUp(people.single), isTrue);
      expect(ticked.isFollowedUp(ticked.entries.single), isTrue);
    });

    test('a tick answers the flag it was given, not a different one', () {
      // Ann's tick was for Gone quiet; she now triggers Not coming recently.
      final event = _event().copyWith(
        checkOnFollowUps: {
          'm1': CheckOnFollowUp(
            flag: CheckOnFlag.goneQuiet.name,
            lastPresent: DateTime(2026, 1, 14),
          ),
        },
      );
      final board = _board([event], _sessions({_ann: 'xx....'}));
      expect(board.entries.single.flag, CheckOnFlag.notComingRecently);
      expect(board.toCheck.single.displayName, 'Ann');
    });

    test('the same flag after attending again reappears', () {
      final first = _board([_event()], _sessions({_ann: 'xx....'}));
      final event = _event().withFollowUps(first.entries);
      expect(
        _board([event], _sessions({_ann: 'xx....'})).toCheck,
        isEmpty,
      );

      // Ann comes once more, then misses three again: same flag, new date.
      final again = _board([event], _sessions({_ann: 'xx.x...'}));
      expect(again.entries.single.flag, CheckOnFlag.notComingRecently);
      expect(again.toCheck.single.displayName, 'Ann');
      expect(again.isFollowedUp(again.entries.single), isFalse);
    });

    test('a new flag on one event brings the person back with that line', () {
      final sessions = [
        ..._sessions({_ann: 'xx....'}),
        ..._sessions({_ann: 'xx....'}, eventId: 'e2', title: 'Prayer'),
      ];
      final events = [_event(), _event(id: 'e2', title: 'Prayer')];
      final all = _board(events, sessions, [_ann]);
      final studyLine = all.entries.firstWhere((e) => e.eventId == 'e1');
      final board = _board(
        [
          events[0].withFollowUps([studyLine]),
          events[1]
        ],
        sessions,
        [_ann],
      );
      final person = board.toCheck.single;
      expect(person.entries.map((e) => e.eventTitle), ['Prayer']);
      // In the report she is one card with both lines, not yet followed up.
      expect(board.people().single.entries, hasLength(2));
      expect(board.isPersonFollowedUp(board.people().single), isFalse);
    });

    test('people() puts followed-up people last and filters by event', () {
      final sessions = [
        ..._sessions({_ann: 'xx.....', _bob: 'xxxx...'}),
        ..._sessions({_ann: 'xx....'}, eventId: 'e2', title: 'Prayer'),
      ];
      final events = [_event(), _event(id: 'e2', title: 'Prayer')];
      final base = _board(events, sessions);
      final annStudy = base.entries
          .firstWhere((e) => e.displayName == 'Ann' && e.eventId == 'e1');
      final annPrayer = base.entries
          .firstWhere((e) => e.displayName == 'Ann' && e.eventId == 'e2');
      final board = _board(
        [
          events[0].withFollowUps([annStudy]),
          events[1].withFollowUps([annPrayer]),
        ],
        sessions,
      );
      expect(board.people().map((p) => p.displayName), ['Bob', 'Ann']);
      expect(board.people(eventId: 'e2').map((p) => p.displayName), ['Ann']);
    });

    test('un-ticking and un-stopping restore the person', () {
      final sessions = _sessions({_ann: 'xx....'});
      final entry = _board([_event()], sessions).entries.single;
      final ticked = _event().withFollowUps([entry]);
      expect(ticked.followUpAnswers(entry), isTrue);
      final cleared = ticked.withoutFollowUps(['m1']);
      expect(cleared.followUpAnswers(entry), isFalse);
      expect(cleared.checkOnFollowUps, isEmpty);

      final stopped = _event().withStopFlagging('m1');
      expect(_board([stopped], sessions).entries, isEmpty);
      final back = stopped.withoutStopFlagging('m1');
      expect(back.checkOnStopFlagging, isEmpty);
      expect(_board([back], sessions).entries, hasLength(1));
    });

    test('un-ticking keeps the other people ticked', () {
      final event = _event().copyWith(
        checkOnFollowUps: {
          'm1': CheckOnFollowUp(flag: 'goneQuiet', lastPresent: _start),
          'm2': CheckOnFollowUp(flag: 'goneQuiet', lastPresent: _start),
        },
      );
      expect(event.withoutFollowUps(['m1']).checkOnFollowUps.keys, ['m2']);
    });
  });
}
