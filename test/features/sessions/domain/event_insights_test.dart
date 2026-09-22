import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/sessions/domain/event_insights.dart';

/// Chronological weekly session dates, oldest first.
DateTime _week(int index) =>
    DateTime(2026, 1, 7).add(Duration(days: 7 * index));

Event _event({
  String id = 'e1',
  String title = 'Wednesday Study',
  List<String> memberIds = const [],
  InsightsConfig? insights,
}) {
  return Event(
    id: id,
    title: title,
    time: const TimeOfDay(hour: 19, minute: 0),
    frequency: 'Weekly',
    memberIds: memberIds,
    insightsConfig: insights,
    createdAt: DateTime(2026, 1, 1),
  );
}

SessionRecord _mark(
  String? memberId,
  String attendee, {
  AttendanceStatus status = AttendanceStatus.present,
  bool isLate = false,
}) {
  return SessionRecord(
    memberId: memberId,
    attendee: attendee,
    status: status,
    recordedAt: DateTime(2026, 1, 1),
    recordedBy: 'user',
    isLate: isLate,
  );
}

Session _session(
  int weekIndex,
  List<SessionRecord> records, {
  String? eventId = 'e1',
  String title = 'Wednesday Study',
  DateTime? deletedAt,
  List<String> excludedMemberIds = const [],
}) {
  return Session(
    id: 's$weekIndex',
    eventId: eventId,
    title: title,
    sessionDate: _week(weekIndex),
    records: records,
    createdAt: _week(weekIndex),
    updatedAt: _week(weekIndex),
    createdBy: 'user',
    deletedAt: deletedAt,
    excludedMemberIds: excludedMemberIds,
  );
}

final _alice = Member(id: 'm1', displayName: 'Alice Okonkwo');
final _bob = Member(id: 'm2', displayName: 'Bob Castellanos');
final _cara = Member(id: 'm3', displayName: 'Cara Lindqvist');
final _roster = [_alice, _bob, _cara];

void main() {
  group('attendance rate', () {
    test('is present roster marks over the whole roster', () {
      // 2 of 3 present -> 67%.
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [
            _mark('m1', 'Alice Okonkwo'),
            _mark('m2', 'Bob Castellanos'),
            _mark('m3', 'Cara Lindqvist', status: AttendanceStatus.absent),
          ]),
        ],
        members: _roster,
      );

      expect(insights.points.single.present, 2);
      expect(insights.points.single.total, 3);
      expect(insights.averageRatePercent, 67);
    });

    test('counts a roster member with no record at all as absent', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [_mark('m1', 'Alice Okonkwo')]),
        ],
        members: _roster,
      );

      expect(insights.points.single.present, 1);
      expect(insights.points.single.total, 3);
    });

    test('excludes guests from both numerator and denominator', () {
      // A guest is only ever recorded present, so counting them could only
      // push the rate up. ADR 0006.
      final withoutGuest = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [
            _mark('m1', 'Alice Okonkwo'),
            _mark('m2', 'Bob Castellanos', status: AttendanceStatus.absent),
            _mark('m3', 'Cara Lindqvist', status: AttendanceStatus.absent),
          ]),
        ],
        members: _roster,
      );
      final withGuest = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [
            _mark('m1', 'Alice Okonkwo'),
            _mark('m2', 'Bob Castellanos', status: AttendanceStatus.absent),
            _mark('m3', 'Cara Lindqvist', status: AttendanceStatus.absent),
            _mark(null, 'Walk-in Wendy'),
          ]),
        ],
        members: _roster,
      );

      expect(withGuest.averageRatePercent, withoutGuest.averageRatePercent);
      expect(withGuest.points.single.total, 3);
      expect(withGuest.guestMarkCount, 1);
    });

    test('honours a session excluding a roster member', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(
            0,
            [_mark('m1', 'Alice Okonkwo')],
            excludedMemberIds: ['m3'],
          ),
        ],
        members: _roster,
      );

      expect(insights.points.single.total, 2);
    });

    test('scopes the roster to the event when it names members', () {
      final insights = EventInsights.from(
        event: _event(memberIds: ['m1', 'm2']),
        sessions: [
          _session(0, [_mark('m1', 'Alice Okonkwo')]),
        ],
        members: _roster,
      );

      expect(insights.points.single.total, 2);
    });

    test('ignores soft-deleted members', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [_mark('m1', 'Alice Okonkwo')]),
        ],
        members: [
          ..._roster,
          Member(id: 'm9', displayName: 'Gone', deletedAt: DateTime(2026, 1, 1))
        ],
      );

      expect(insights.points.single.total, 3);
    });

    test('reports no average when the event has no sessions', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: const [],
        members: _roster,
      );

      expect(insights.points, isEmpty);
      expect(insights.averageRatePercent, isNull);
      expect(insights.bestSession, isNull);
      expect(insights.lowestSession, isNull);
      expect(insights.medianPresentCount, isNull);
    });

    test('reports a whole-roster absence as zero rather than no data', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [
            _mark('m1', 'Alice Okonkwo', status: AttendanceStatus.absent),
          ]),
        ],
        members: _roster,
      );

      expect(insights.averageRatePercent, 0);
    });
  });

  group('session scope', () {
    test('excludes soft-deleted sessions', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [_mark('m1', 'Alice Okonkwo')]),
          _session(1, [_mark('m1', 'Alice Okonkwo')],
              deletedAt: DateTime(2026, 2, 1)),
        ],
        members: _roster,
      );

      expect(insights.points, hasLength(1));
    });

    test(
        'includes legacy sessions matched by title when they carry no event id',
        () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [_mark('m1', 'Alice Okonkwo')], eventId: null),
          _session(1, [_mark('m1', 'Alice Okonkwo')]),
        ],
        members: _roster,
      );

      expect(insights.points, hasLength(2));
    });

    test('excludes sessions belonging to another event', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [_mark('m1', 'Alice Okonkwo')]),
          _session(1, [_mark('m1', 'Alice Okonkwo')],
              eventId: 'other', title: 'Sunday'),
        ],
        members: _roster,
      );

      expect(insights.points, hasLength(1));
    });

    test('orders points chronologically and trims to the configured range', () {
      final sessions = [
        for (var i = 0; i < 20; i++)
          _session(i, [_mark('m1', 'Alice Okonkwo')]),
      ].reversed.toList();

      final insights = EventInsights.from(
        event: _event(
            insights: const InsightsConfig(range: InsightsRange.twelveWeeks)),
        sessions: sessions,
        members: _roster,
      );

      expect(insights.points, hasLength(12));
      expect(insights.points.first.session.sessionDate, _week(8));
      expect(insights.points.last.session.sessionDate, _week(19));
    });
  });

  group('lateness', () {
    test('counts a late mark as a full present', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [
            _mark('m1', 'Alice Okonkwo', isLate: true),
            _mark('m2', 'Bob Castellanos'),
            _mark('m3', 'Cara Lindqvist'),
          ]),
        ],
        members: _roster,
      );

      expect(insights.averageRatePercent, 100);
    });

    test('reports lateness as its own rate over present marks', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [
            _mark('m1', 'Alice Okonkwo', isLate: true),
            _mark('m2', 'Bob Castellanos'),
            _mark('m3', 'Cara Lindqvist'),
            _mark(null, 'Walk-in Wendy'),
          ]),
        ],
        members: _roster,
      );

      // Guests count in the lateness denominator: unlike the attendance rate
      // they cannot skew it in one direction, and lateness is about everyone
      // who was in the room.
      expect(insights.lateMarkCount, 1);
      expect(insights.presentMarkCount, 4);
      expect(insights.lateRatePercent, 25);
    });

    test('reports no late rate when nobody was present', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [
            _mark('m1', 'Alice Okonkwo', status: AttendanceStatus.absent),
          ]),
        ],
        members: _roster,
      );

      expect(insights.lateRatePercent, isNull);
    });
  });

  group('regulars', () {
    List<Session> everyWeekExceptCara(int count) {
      return [
        for (var i = 0; i < count; i++)
          _session(i, [
            _mark('m1', 'Alice Okonkwo'),
            _mark('m2', 'Bob Castellanos'),
            _mark('m3', 'Cara Lindqvist', status: AttendanceStatus.absent),
          ]),
      ];
    }

    test('lists members meeting the configured threshold over the window', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: everyWeekExceptCara(8),
        members: _roster,
      );

      expect(
        insights.regulars.map((r) => r.member.id),
        containsAll(<String>['m1', 'm2']),
      );
      expect(insights.regulars.map((r) => r.member.id), isNot(contains('m3')));
    });

    test('honours a lowered threshold from configuration', () {
      final sessions = [
        for (var i = 0; i < 8; i++)
          _session(i, [
            _mark('m1', 'Alice Okonkwo'),
            _mark(
              'm3',
              'Cara Lindqvist',
              status:
                  i < 5 ? AttendanceStatus.present : AttendanceStatus.absent,
            ),
          ]),
      ];

      final strict = EventInsights.from(
        event: _event(),
        sessions: sessions,
        members: _roster,
      );
      final relaxed = EventInsights.from(
        event: _event(
          insights: const InsightsConfig(regularThresholdPercent: 60),
        ),
        sessions: sessions,
        members: _roster,
      );

      expect(strict.regulars.map((r) => r.member.id), isNot(contains('m3')));
      expect(relaxed.regulars.map((r) => r.member.id), contains('m3'));
    });

    test('reports how many more sessions are needed when the window is short',
        () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: everyWeekExceptCara(3),
        members: _roster,
      );

      expect(insights.regulars, isEmpty);
      expect(insights.sessionsNeededFor(InsightsSection.regulars), 5);
    });

    test('needs nothing more once the window is satisfied', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: everyWeekExceptCara(8),
        members: _roster,
      );

      expect(insights.sessionsNeededFor(InsightsSection.regulars), 0);
    });
  });

  group('lapsed attendees', () {
    List<Session> regularThenAbsent({
      required int attended,
      required int missed,
    }) {
      return [
        for (var i = 0; i < attended; i++)
          _session(i, [
            _mark('m1', 'Alice Okonkwo'),
            _mark('m2', 'Bob Castellanos'),
          ]),
        for (var i = attended; i < attended + missed; i++)
          _session(i, [
            _mark('m1', 'Alice Okonkwo', status: AttendanceStatus.absent),
            _mark('m2', 'Bob Castellanos'),
          ]),
      ];
    }

    test('flags a former regular who missed the configured run', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: regularThenAbsent(attended: 6, missed: 3),
        members: _roster,
      );

      expect(insights.lapsed.map((l) => l.member.id), ['m1']);
      expect(insights.lapsed.single.consecutiveMisses, 3);
      expect(insights.lapsed.single.lastSeen, _week(5));
    });

    test('does not flag someone still short of the run', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: regularThenAbsent(attended: 6, missed: 2),
        members: _roster,
      );

      expect(insights.lapsed, isEmpty);
    });

    test('does not flag someone who was never a regular', () {
      // Cara attends rarely, then stops: never qualified, so never lapsed.
      final sessions = [
        for (var i = 0; i < 5; i++)
          _session(i, [
            _mark('m3', 'Cara Lindqvist',
                status: i == 0
                    ? AttendanceStatus.present
                    : AttendanceStatus.absent),
          ]),
        for (var i = 5; i < 8; i++)
          _session(i, [
            _mark('m3', 'Cara Lindqvist', status: AttendanceStatus.absent),
          ]),
      ];

      final insights = EventInsights.from(
        event: _event(),
        sessions: sessions,
        members: _roster,
      );

      expect(insights.lapsed.map((l) => l.member.id), isNot(contains('m3')));
    });

    test('renders no verdict below the minimum prior history', () {
      // Only 3 prior sessions before the run of misses: not enough to judge.
      final insights = EventInsights.from(
        event: _event(),
        sessions: regularThenAbsent(attended: 3, missed: 3),
        members: _roster,
      );

      expect(insights.lapsed, isEmpty);
      expect(
          insights.sessionsNeededFor(InsightsSection.lapsed), greaterThan(0));
    });

    test('honours a configured miss count', () {
      final insights = EventInsights.from(
        event: _event(
          insights: const InsightsConfig(lapsedConsecutiveMisses: 2),
        ),
        sessions: regularThenAbsent(attended: 6, missed: 2),
        members: _roster,
      );

      expect(insights.lapsed.map((l) => l.member.id), ['m1']);
    });
  });

  group('first seen and first timers', () {
    test('derives first seen from the earliest mark for that person', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [_mark('m1', 'Alice Okonkwo')]),
          _session(1, [
            _mark('m1', 'Alice Okonkwo'),
            _mark('m2', 'Bob Castellanos'),
          ]),
        ],
        members: _roster,
      );

      expect(insights.firstSeenFor('m1'), _week(0));
      expect(insights.firstSeenFor('m2'), _week(1));
    });

    test('has no first seen for a roster member never marked present', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [_mark('m1', 'Alice Okonkwo')]),
        ],
        members: _roster,
      );

      expect(insights.firstSeenFor('m3'), isNull);
    });

    test('lists people first seen inside the range, guests included', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [_mark('m1', 'Alice Okonkwo')]),
          _session(1, [
            _mark('m1', 'Alice Okonkwo'),
            _mark(null, 'Walk-in Wendy'),
          ]),
        ],
        members: _roster,
      );

      expect(
        insights.firstTimers.map((f) => f.name),
        containsAll(<String>['Alice Okonkwo', 'Walk-in Wendy']),
      );
      expect(
        insights.firstTimers
            .singleWhere((f) => f.name == 'Walk-in Wendy')
            .firstSeen,
        _week(1),
      );
    });

    test('does not call someone a first timer when they predate the range', () {
      final sessions = [
        for (var i = 0; i < 20; i++)
          _session(i, [_mark('m1', 'Alice Okonkwo')]),
      ];

      final insights = EventInsights.from(
        event: _event(
            insights: const InsightsConfig(range: InsightsRange.twelveWeeks)),
        sessions: sessions,
        members: _roster,
      );

      expect(insights.firstTimers, isEmpty);
    });
  });

  group('member table', () {
    test('covers the whole roster, ordered by rate then name', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          for (var i = 0; i < 4; i++)
            _session(i, [
              _mark('m1', 'Alice Okonkwo'),
              _mark('m2', 'Bob Castellanos',
                  status: i < 2
                      ? AttendanceStatus.present
                      : AttendanceStatus.absent),
            ]),
        ],
        members: _roster,
      );

      expect(insights.memberTable.map((m) => m.member.id), ['m1', 'm2', 'm3']);
      expect(insights.memberTable.first.ratePercent, 100);
      expect(insights.memberTable[1].ratePercent, 50);
      expect(insights.memberTable.last.ratePercent, 0);
    });

    test('reports the longest current streak', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          for (var i = 0; i < 4; i++)
            _session(i, [
              _mark('m1', 'Alice Okonkwo'),
              _mark('m2', 'Bob Castellanos',
                  status: i == 0
                      ? AttendanceStatus.absent
                      : AttendanceStatus.present),
            ]),
        ],
        members: _roster,
      );

      expect(insights.longestCurrentStreak?.member.id, 'm1');
      expect(insights.longestCurrentStreak?.currentStreak, 4);
    });
  });

  group('median and growth', () {
    test('reports the median number present', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [_mark('m1', 'Alice Okonkwo')]),
          _session(1, [
            _mark('m1', 'Alice Okonkwo'),
            _mark('m2', 'Bob Castellanos'),
          ]),
          _session(2, [
            _mark('m1', 'Alice Okonkwo'),
            _mark('m2', 'Bob Castellanos'),
            _mark('m3', 'Cara Lindqvist'),
          ]),
        ],
        members: _roster,
      );

      expect(insights.medianPresentCount, 2);
    });

    test('accumulates distinct people seen over the range', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [_mark('m1', 'Alice Okonkwo')]),
          _session(1, [
            _mark('m1', 'Alice Okonkwo'),
            _mark('m2', 'Bob Castellanos'),
          ]),
        ],
        members: _roster,
      );

      expect(insights.points.map((p) => p.cumulativePeopleSeen), [1, 2]);
    });
  });

  group('section visibility', () {
    test('hides guests and lateness when their counts are zero', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [_mark('m1', 'Alice Okonkwo')]),
        ],
        members: _roster,
      );

      expect(insights.isVisible(InsightsSection.guests), isFalse);
      expect(insights.isVisible(InsightsSection.lateness), isFalse);
    });

    test('shows guests and lateness once they have something to say', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [
            _mark('m1', 'Alice Okonkwo', isLate: true),
            _mark(null, 'Walk-in Wendy'),
          ]),
        ],
        members: _roster,
      );

      expect(insights.isVisible(InsightsSection.guests), isTrue);
      expect(insights.isVisible(InsightsSection.lateness), isTrue);
    });

    test('shows the default set and hides the opt-in set', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          for (var i = 0; i < 8; i++)
            _session(i, [_mark('m1', 'Alice Okonkwo')]),
        ],
        members: _roster,
      );

      expect(insights.isVisible(InsightsSection.rateOverTime), isTrue);
      expect(insights.isVisible(InsightsSection.extremes), isTrue);
      expect(insights.isVisible(InsightsSection.regulars), isTrue);
      expect(insights.isVisible(InsightsSection.lapsed), isTrue);
      expect(insights.isVisible(InsightsSection.memberTable), isTrue);
      expect(insights.isVisible(InsightsSection.growth), isFalse);
      expect(insights.isVisible(InsightsSection.streaks), isFalse);
      expect(insights.isVisible(InsightsSection.medianSize), isFalse);
      expect(insights.isVisible(InsightsSection.firstTimers), isFalse);
    });

    test('respects an explicit choice in configuration', () {
      final insights = EventInsights.from(
        event: _event(
          insights: const InsightsConfig(
            visibleSections: {
              InsightsSection.rateOverTime,
              InsightsSection.streaks
            },
          ),
        ),
        sessions: [
          for (var i = 0; i < 8; i++)
            _session(i, [_mark('m1', 'Alice Okonkwo')]),
        ],
        members: _roster,
      );

      expect(insights.isVisible(InsightsSection.rateOverTime), isTrue);
      expect(insights.isVisible(InsightsSection.streaks), isTrue);
      expect(insights.isVisible(InsightsSection.regulars), isFalse);
    });
  });

  group('trend', () {
    test('compares the later half against the earlier half', () {
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          for (var i = 0; i < 4; i++)
            _session(i, [
              _mark('m1', 'Alice Okonkwo',
                  status: i < 2
                      ? AttendanceStatus.absent
                      : AttendanceStatus.present),
            ]),
        ],
        members: _roster,
      );

      expect(insights.priorAverageRatePercent, 0);
      expect(insights.averageRatePercent, 17);
      expect(insights.isImproving, isTrue);
    });
  });

  group('exclusions and legacy links', () {
    test('a session that excluded someone counts against them nowhere', () {
      // Excluded is not absent. Regulars must agree with the member table
      // about the same person — the defect class ADR 0006 exists to prevent.
      // Bob is excluded from two of eight sessions and attends every session
      // he was eligible for. Counting an exclusion as an absence would read
      // 6/8 = 75% and drop him below the 80% bar.
      final sessions = [
        for (var i = 0; i < 8; i++)
          _session(
            i,
            [
              _mark('m1', 'Alice Okonkwo'),
              if (i > 1) _mark('m2', 'Bob Castellanos'),
            ],
            excludedMemberIds: i < 2 ? ['m2'] : const [],
          ),
      ];

      final insights = EventInsights.from(
        event: _event(),
        sessions: sessions,
        members: _roster,
      );

      final bob =
          insights.memberTable.firstWhere((m) => m.member.id == 'm2');
      expect(bob.attended, 6);
      expect(bob.eligible, 6);
      expect(bob.ratePercent, 100);
      expect(insights.regulars.map((r) => r.member.id), contains('m2'));
    });

    test('a roster member recorded without a member id is not a guest', () {
      // Pre-identifier marks link by name. Treating them as guests would
      // inflate guests and first-timers under the legacy fallback.
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [_mark(null, 'Alice Okonkwo')]),
        ],
        members: _roster,
      );

      expect(insights.guestMarkCount, 0);
      expect(insights.points.single.present, 1);
      expect(insights.firstTimers.single.name, 'Alice Okonkwo');
      expect(insights.firstTimers.single.isGuest, isFalse);
      expect(insights.firstSeenFor('m1'), _week(0));
    });

    test('counts everyone in the room for median session size', () {
      // A headcount is a headcount: ADR 0006 scopes guest exclusion to rates.
      final insights = EventInsights.from(
        event: _event(),
        sessions: [
          _session(0, [
            _mark('m1', 'Alice Okonkwo'),
            _mark(null, 'Walk-in Wendy'),
          ]),
        ],
        members: _roster,
      );

      expect(insights.medianPresentCount, 2);
    });
  });
}
