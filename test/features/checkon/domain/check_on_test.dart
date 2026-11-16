import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/checkon/domain/check_on.dart';
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

SessionRecord _mark(String? memberId, String attendee, {bool present = true}) {
  return SessionRecord(
    memberId: memberId,
    attendee: attendee,
    status: present ? AttendanceStatus.present : AttendanceStatus.absent,
    recordedAt: _start,
    recordedBy: 'user',
  );
}

Session _session(
  int index,
  DateTime date,
  List<SessionRecord> records, {
  String? eventId = 'e1',
  String title = 'Study',
  DateTime? deletedAt,
  List<String> excludedMemberIds = const [],
}) {
  return Session(
    id: 's$index-${date.toIso8601String()}',
    eventId: eventId,
    title: title,
    sessionDate: date,
    records: records,
    createdAt: date,
    updatedAt: date,
    createdBy: 'user',
    deletedAt: deletedAt,
    excludedMemberIds: excludedMemberIds,
  );
}

/// One session per character, oldest first: `x` present, `.` an absent mark,
/// `-` no record at all. Sessions are a week apart unless [days] gives each
/// session's day offset from [_start].
List<Session> _sessions(Map<Member, String> patterns, {List<int>? days}) {
  final n = patterns.values.first.length;
  return [
    for (var i = 0; i < n; i++)
      _session(
        i,
        _start.add(Duration(days: days?[i] ?? 7 * i)),
        [
          for (final e in patterns.entries)
            if (e.value[i] != '-')
              _mark(e.key.id, e.key.displayName, present: e.value[i] == 'x'),
        ],
      ),
  ];
}

DateTime _day(int offset) => _start.add(Duration(days: offset));

/// Ann's single result for [pattern], or null when she is not flagged.
CheckOnEntry? _annFor(String pattern, {List<int>? days}) {
  final entries = checkOnForEvent(
    event: _event(),
    members: [_ann],
    sessions: _sessions({_ann: pattern}, days: days),
  );
  return entries.isEmpty ? null : entries.single;
}

const _came = CheckOnSlot.came;
const _lately = CheckOnSlot.missedLately;
const _earlier = CheckOnSlot.missedEarlier;
const _notYet = CheckOnSlot.noMeetingYet;

void main() {
  group('flags', () {
    test('carry their tone', () {
      expect(CheckOnFlag.notComingRecently.tone, CheckOnTone.strong);
      expect(CheckOnFlag.suddenDrop.tone, CheckOnTone.strong);
      expect(CheckOnFlag.goneQuiet.tone, CheckOnTone.soft);
      expect(CheckOnFlag.newcomerFollowUp.tone, CheckOnTone.soft);
      expect(CheckOnFlag.oneTimeVisitor.tone, CheckOnTone.soft);
      expect(CheckOnFlag.goneQuiet.label, 'Gone quiet');
    });
  });

  group('Not coming recently', () {
    test('came twice then missed the last 3', () {
      final e = _annFor('xx...')!;
      expect(e.flag, CheckOnFlag.notComingRecently);
      expect(e.tone, CheckOnTone.strong);
      expect(e.reason, 'Missed the last 3 · last here Jan 14');
      expect(e.lastPresent, _day(7));
      expect(e.memberId, 'm1');
      expect(e.displayName, 'Ann');
      expect(e.eventId, 'e1');
      expect(e.eventTitle, 'Study');
    });

    test('reports the whole run of misses', () {
      expect(_annFor('xx....')!.reason, 'Missed the last 4 · last here Jan 14');
    });

    test('two misses are not enough', () {
      expect(_annFor('xxx..'), isNull);
    });

    test('coming only once is not enough', () {
      expect(_annFor('x....'), isNull);
    });
  });

  group('Sudden drop', () {
    test('came to 75% of the previous 8, then missed 3 of the last 4', () {
      final e = _annFor('xx.xx.xx' '..x.')!;
      expect(e.flag, CheckOnFlag.suddenDrop);
      expect(e.tone, CheckOnTone.strong);
      expect(e.reason, 'Missed 3 of the last 4 · last here Mar 18');
      expect(e.lastPresent, _day(70));
    });

    test('below 75% of the previous 8 is not flagged', () {
      expect(_annFor('xx.x..xx' '..x.'), isNull);
    });

    test('missing only 2 of the last 4 is not flagged', () {
      expect(_annFor('xxxxxxxx' '.x.x'), isNull);
    });

    test('needs eight earlier meetings', () {
      expect(_annFor('xxxxxxx' '..x.'), isNull);
    });
  });

  group('Gone quiet', () {
    test('came 3 times, not seen for 6 weeks', () {
      final e = _annFor('xxx..', days: [0, 7, 14, 35, 56])!;
      expect(e.flag, CheckOnFlag.goneQuiet);
      expect(e.tone, CheckOnTone.soft);
      expect(e.reason, 'Not seen for 6 weeks · last here Jan 21');
      expect(e.lastPresent, _day(14));
    });

    test('rounds weeks down', () {
      expect(
        _annFor('xxx..', days: [0, 7, 14, 35, 69])!.reason,
        'Not seen for 7 weeks · last here Jan 21',
      );
    });

    test('a day under 6 weeks is not flagged', () {
      expect(_annFor('xxx..', days: [0, 7, 14, 35, 55]), isNull);
    });

    test('coming only twice is not enough', () {
      expect(_annFor('xx..', days: [0, 7, 28, 49]), isNull);
    });

    test('one miss after a long break in meetings is not flagged', () {
      expect(_annFor('xxx.', days: [0, 7, 14, 70]), isNull);
    });
  });

  group('Newcomer follow-up', () {
    test('came once, at the latest meeting', () {
      final e = _annFor('---x')!;
      expect(e.flag, CheckOnFlag.newcomerFollowUp);
      expect(e.tone, CheckOnTone.soft);
      expect(e.reason, 'First time on Jan 28');
      expect(e.lastPresent, _day(21));
    });

    test('first seen 3 weeks before the latest meeting', () {
      expect(_annFor('x---')!.flag, CheckOnFlag.newcomerFollowUp);
    });

    test('first seen 4 weeks before is no longer new', () {
      expect(_annFor('x----'), isNull);
    });
  });

  group('One-time visitor', () {
    test('came once, not seen for 8 weeks', () {
      final e = _annFor('x--------')!;
      expect(e.flag, CheckOnFlag.oneTimeVisitor);
      expect(e.tone, CheckOnTone.soft);
      expect(e.reason, 'Came once · Jan 7');
      expect(e.lastPresent, _start);
    });

    test('7 weeks is not flagged', () {
      expect(_annFor('x-------'), isNull);
    });

    test('one miss after a long break in meetings is not flagged', () {
      expect(_annFor('--x.', days: [0, 7, 14, 84]), isNull);
    });
  });

  group('precedence', () {
    test('Not coming recently beats Gone quiet', () {
      expect(_annFor('xxx......')!.flag, CheckOnFlag.notComingRecently);
    });

    test('Not coming recently beats Sudden drop', () {
      expect(_annFor('xxxxxxxx' '....')!.flag, CheckOnFlag.notComingRecently);
    });
  });

  group('who and what counts', () {
    test('no flags for an event with fewer than 4 sessions', () {
      expect(_annFor('--x'), isNull);
    });

    test('nobody who never came is flagged', () {
      expect(_annFor('.....'), isNull);
    });

    test('guests and marks without a live member are never flagged', () {
      final sessions = [
        for (var i = 0; i < 5; i++)
          _session(i, _day(7 * i), [
            if (i < 2) _mark(null, 'Walk-in'),
            if (i < 2) _mark('ghost', 'Gone member'),
            if (i < 2) _mark('m9', 'Deleted'),
          ]),
      ];
      final deleted =
          Member(id: 'm9', displayName: 'Deleted', deletedAt: _start);
      final entries = checkOnForEvent(
        event: _event(),
        members: [_ann, deleted],
        sessions: sessions,
      );
      expect(entries, isEmpty);
    });

    test('a name-only mark counts for the roster member with that name', () {
      final sessions = [
        for (var i = 0; i < 5; i++)
          _session(i, _day(7 * i), [if (i < 2) _mark(null, 'Ann')]),
      ];
      final entries = checkOnForEvent(
        event: _event(),
        members: [_ann],
        sessions: sessions,
      );
      expect(entries.single.flag, CheckOnFlag.notComingRecently);
    });

    test('a member listed twice is counted once', () {
      final entries = checkOnForEvent(
        event: _event(),
        members: [_ann, _ann],
        sessions: _sessions({_ann: 'xx...'}),
      );
      expect(entries, hasLength(1));
    });

    test('only members on the event roster are flagged', () {
      final event = _event().copyWith(memberIds: ['m2']);
      final entries = checkOnForEvent(
        event: event,
        members: [_ann, _bob],
        sessions: _sessions({_ann: 'xx...', _bob: 'xx...'}),
      );
      expect(entries.single.memberId, 'm2');
    });

    test('deleted sessions are ignored', () {
      final sessions = [
        ..._sessions({_ann: 'xx...'}),
        _session(9, _day(60), [_mark('m1', 'Ann')], deletedAt: _day(61)),
      ];
      final e = checkOnForEvent(
        event: _event(),
        members: [_ann],
        sessions: sessions,
      ).single;
      expect(e.flag, CheckOnFlag.notComingRecently);
      expect(e.lastPresent, _day(7));
    });

    test('deleted sessions do not count toward the 4-session minimum', () {
      final sessions = [
        ..._sessions({_ann: '--x'}),
        _session(9, _day(1), [], deletedAt: _day(2)),
      ];
      expect(
        checkOnForEvent(event: _event(), members: [_ann], sessions: sessions),
        isEmpty,
      );
    });

    test('other events are ignored; untagged sessions match by title', () {
      final sessions = [
        _session(0, _day(0), [_mark('m1', 'Ann')], eventId: null),
        _session(1, _day(7), [_mark('m1', 'Ann')]),
        _session(2, _day(14), []),
        _session(3, _day(21), []),
        _session(4, _day(28), []),
        _session(5, _day(35), [_mark('m1', 'Ann')], eventId: 'e2'),
        _session(6, _day(42), [_mark('m1', 'Ann')],
            eventId: null, title: 'Other'),
      ];
      final e = checkOnForEvent(
        event: _event(),
        members: [_ann],
        sessions: sessions,
      ).single;
      expect(e.reason, 'Missed the last 3 · last here Jan 14');
    });

    test('a session that excluded the member is not a miss', () {
      final sessions = _sessions({_ann: 'xx...'});
      sessions[4] = sessions[4].copyWith(excludedMemberIds: ['m1']);
      expect(
        checkOnForEvent(event: _event(), members: [_ann], sessions: sessions),
        isEmpty,
      );
    });
  });

  group('history', () {
    test('pads with no meeting yet before the first appearance', () {
      expect(
        _annFor('-x.x...')!.history,
        [_notYet, _notYet, _came, _earlier, _came, _lately, _lately, _lately],
      );
    });

    test('keeps only the last eight meetings', () {
      expect(
        _annFor('--xx.xx...')!.history,
        [_came, _came, _earlier, _came, _came, _lately, _lately, _lately],
      );
    });

    test('marks only the sudden-drop misses as lately', () {
      expect(
        _annFor('xx.xx.xx' '..x.')!.history,
        [_came, _earlier, _came, _came, _lately, _lately, _came, _lately],
      );
    });

    test('a newcomer has no lately misses', () {
      expect(
        _annFor('---x...')!.history,
        [
          _notYet,
          _notYet,
          _notYet,
          _notYet,
          _came,
          _earlier,
          _earlier,
          _earlier
        ],
      );
    });

    test('a one-time visitor shows the misses since as lately', () {
      expect(
        _annFor('x--------')!.history,
        [
          _lately,
          _lately,
          _lately,
          _lately,
          _lately,
          _lately,
          _lately,
          _lately
        ],
      );
    });
  });

  group('ordering', () {
    test('one event lists most serious first, then longest away', () {
      final cara = Member(id: 'm3', displayName: 'Cara');
      final entries = checkOnForEvent(
        event: _event(),
        members: [_ann, _bob, cara],
        sessions: _sessions({
          _ann: '------x',
          _bob: '-xx....',
          cara: 'xx.....',
        }),
      );
      expect(entries.map((e) => e.displayName), ['Cara', 'Bob', 'Ann']);
    });
  });

  group('groupByPerson', () {
    CheckOnEntry entry(
      String memberId,
      String name,
      String eventTitle,
      CheckOnFlag flag, {
      int lastPresentDay = 0,
    }) {
      return CheckOnEntry(
        eventId: eventTitle.toLowerCase(),
        eventTitle: eventTitle,
        memberId: memberId,
        displayName: name,
        flag: flag,
        reason: 'r',
        lastPresent: _day(lastPresentDay),
        history: const [],
      );
    }

    test('one entry per person, most serious person first', () {
      final people = groupByPerson([
        entry('m2', 'Bob', 'Study', CheckOnFlag.goneQuiet),
        entry('m1', 'Ann', 'Study', CheckOnFlag.newcomerFollowUp),
        entry('m3', 'Cara', 'Choir', CheckOnFlag.suddenDrop),
        entry('m1', 'Ann', 'Choir', CheckOnFlag.notComingRecently),
      ]);
      expect(people.map((p) => p.displayName), ['Ann', 'Cara', 'Bob']);
      final ann = people.first;
      expect(ann.memberId, 'm1');
      expect(ann.flag, CheckOnFlag.notComingRecently);
      expect(ann.tone, CheckOnTone.strong);
      expect(ann.entries.map((e) => e.eventTitle), ['Choir', 'Study']);
    });

    test('ties go to who has been away longest, then name, then event', () {
      final people = groupByPerson([
        entry('m1', 'Ann', 'Study', CheckOnFlag.goneQuiet, lastPresentDay: 9),
        entry('m3', 'Cara', 'Study', CheckOnFlag.goneQuiet),
        entry('m2', 'Bob', 'Study', CheckOnFlag.goneQuiet),
        entry('m2', 'Bob', 'Choir', CheckOnFlag.goneQuiet),
      ]);
      expect(people.map((p) => p.displayName), ['Bob', 'Cara', 'Ann']);
      expect(people.first.entries.map((e) => e.eventTitle), ['Choir', 'Study']);
    });

    test('nothing in, nothing out', () {
      expect(groupByPerson(const []), isEmpty);
    });
  });
}
