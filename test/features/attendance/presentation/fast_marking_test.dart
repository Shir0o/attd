import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/marking_mode.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/presentation/attendance_deck_page.dart';
import 'package:attendance_tracker/features/attendance/presentation/swipeable_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/mocks.dart';

// ── Fixtures ────────────────────────────────────────────────────────────────

Family get _nguyens => Family(
      id: 'f-nguyen',
      displayName: 'Nguyen',
      members: [
        Member(id: 'an', displayName: 'An Nguyen'),
        Member(id: 'duc', displayName: 'Duc Nguyen'),
        Member(id: 'bao', displayName: 'Bao Nguyen'),
      ],
    );

Family get _okafor => Family(
      id: 'f-okafor',
      displayName: 'Okafor',
      isAutoSingleton: true,
      members: [Member(id: 'sam', displayName: 'Sam Okafor')],
    );

List<Member> get _roster => [..._nguyens.members, ..._okafor.members];

Session _session({AttendanceStatus seed = AttendanceStatus.absent}) {
  final at = DateTime(2026, 3, 1);
  return Session(
    id: 'current',
    title: 'Sunday Service',
    sessionDate: at,
    createdAt: at,
    updatedAt: at,
    createdBy: 'User',
    records: [
      for (final m in _roster)
        SessionRecord(
          memberId: m.id,
          attendee: m.displayName,
          status: seed,
          recordedAt: at,
          recordedBy: 'System (Preseed)',
        ),
    ],
  );
}

/// Four past sessions: 'duc' always present, 'an' never, 'bao' half the time —
/// so the likelihood ordering has something real to sort on.
List<Session> _history() => [
      for (var d = 1; d <= 4; d++)
        Session(
          id: 'past-$d',
          title: 'Sunday Service',
          sessionDate: DateTime(2026, 2, d),
          createdAt: DateTime(2026, 2, d),
          updatedAt: DateTime(2026, 2, d),
          createdBy: 'User',
          records: [
            for (final (id, name, present) in [
              ('duc', 'Duc Nguyen', true),
              ('an', 'An Nguyen', false),
              ('bao', 'Bao Nguyen', d.isEven),
            ])
              SessionRecord(
                memberId: id,
                attendee: name,
                status: present
                    ? AttendanceStatus.present
                    : AttendanceStatus.absent,
                recordedAt: DateTime(2026, 2, d),
                recordedBy: 'User',
              ),
          ],
        ),
    ];

typedef Harness = ({MockSessionRepository sessions});

Future<Harness> pumpMode(
  WidgetTester tester,
  MarkingMode mode, {
  AttendanceStatus seed = AttendanceStatus.absent,
  bool withHistory = false,
}) async {
  final sessions = MockSessionRepository();
  if (withHistory) sessions.setSessions(_history());

  await tester.pumpWidget(
    MaterialApp(
      home: AttendanceDeckPage(
        session: _session(seed: seed),
        members: _roster,
        families: [_nguyens, _okafor],
        sessionRepository: sessions,
        attendanceRepository: MockAttendanceRepository(),
        eventRepository: MockEventRepository(),
        markingMode: mode,
        disableAnimations: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (sessions: sessions);
}

/// The status the session was last *saved* with — the thing the summary page
/// and every other surface will read back.
Future<AttendanceStatus?> savedStatus(
  MockSessionRepository repo,
  String memberId,
) async {
  final session = await repo.findSessionById('current');
  if (session == null) return null;
  for (final r in session.records) {
    if (r.memberId == memberId) return r.status;
  }
  return null;
}

Future<void> typeQuery(WidgetTester tester, Key field, String query) async {
  await tester.enterText(find.byKey(field), query);
  await tester.pumpAndSettle();
}

void main() {
  group('marking mode picks the opening surface', () {
    testWidgets('"off" opens on the Deck with only two segments',
        (tester) async {
      await pumpMode(tester, MarkingMode.none);
      expect(find.byType(SwipeableCard), findsOneWidget);
      expect(find.text('Deck'), findsOneWidget);
      expect(find.text('List'), findsOneWidget);
      expect(find.text('Likely'), findsNothing);
    });

    testWidgets('a fast mode opens on its own surface, not the Deck',
        (tester) async {
      await pumpMode(tester, MarkingMode.likelyHere);
      expect(find.byType(SwipeableCard), findsNothing);
      expect(find.byKey(const Key('likelyHereChip_an')), findsOneWidget);
    });

    testWidgets('the third segment is labelled for the chosen mode',
        (tester) async {
      await pumpMode(tester, MarkingMode.initialsPad);
      expect(find.text('Initials'), findsOneWidget);
    });

    testWidgets('switching back to the Deck keeps marks already made',
        (tester) async {
      final h = await pumpMode(tester, MarkingMode.likelyHere);
      await tester.tap(find.byKey(const Key('likelyHereChip_an')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deck'));
      await tester.pumpAndSettle();

      expect(find.byType(SwipeableCard), findsOneWidget);
      expect(await savedStatus(h.sessions, 'an'), AttendanceStatus.present);
    });

    testWidgets('switching to the List shows the same marks', (tester) async {
      await pumpMode(tester, MarkingMode.likelyHere);
      await tester.tap(find.byKey(const Key('likelyHereChip_an')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();

      expect(find.text('Marked present'), findsOneWidget);
    });
  });

  group('rapid entry', () {
    testWidgets('shows nothing until a query is typed', (tester) async {
      await pumpMode(tester, MarkingMode.rapidEntry);
      expect(find.byKey(const Key('fastMarkingResult_an')), findsNothing);
    });

    testWidgets('filters the roster as you type', (tester) async {
      await pumpMode(tester, MarkingMode.rapidEntry);
      await typeQuery(tester, const Key('rapidEntryField'), 'ngu');

      expect(find.byKey(const Key('fastMarkingResult_an')), findsOneWidget);
      expect(find.byKey(const Key('fastMarkingResult_sam')), findsNothing);
    });

    testWidgets('tapping a result marks that person present', (tester) async {
      final h = await pumpMode(tester, MarkingMode.rapidEntry);
      await typeQuery(tester, const Key('rapidEntryField'), 'duc');
      await tester.tap(find.byKey(const Key('fastMarkingResult_duc')));
      await tester.pumpAndSettle();

      expect(await savedStatus(h.sessions, 'duc'), AttendanceStatus.present);
    });

    testWidgets('clears the query after a mark so the next name can be typed',
        (tester) async {
      await pumpMode(tester, MarkingMode.rapidEntry);
      await typeQuery(tester, const Key('rapidEntryField'), 'duc');
      await tester.tap(find.byKey(const Key('fastMarkingResult_duc')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('rapidEntryField')),
      );
      expect(field.controller!.text, isEmpty);
      expect(find.byKey(const Key('fastMarkingResult_an')), findsNothing);
    });

    testWidgets('keeps focus on the field after a mark', (tester) async {
      await pumpMode(tester, MarkingMode.rapidEntry);
      await typeQuery(tester, const Key('rapidEntryField'), 'duc');
      await tester.tap(find.byKey(const Key('fastMarkingResult_duc')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('rapidEntryField')),
      );
      expect(field.focusNode!.hasFocus, isTrue);
    });

    testWidgets('the return key marks the only match', (tester) async {
      final h = await pumpMode(tester, MarkingMode.rapidEntry);
      await typeQuery(tester, const Key('rapidEntryField'), 'sam');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(await savedStatus(h.sessions, 'sam'), AttendanceStatus.present);
    });

    testWidgets('the return key does nothing when the top hits tie',
        (tester) async {
      final h = await pumpMode(tester, MarkingMode.rapidEntry);
      // Three Nguyens all match "ngu" as a word prefix — no unambiguous winner.
      await typeQuery(tester, const Key('rapidEntryField'), 'ngu');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(await savedStatus(h.sessions, 'an'), isNull);
      expect(await savedStatus(h.sessions, 'duc'), isNull);
    });

    testWidgets('an already-marked person reads as here and toggles back',
        (tester) async {
      final h = await pumpMode(
        tester,
        MarkingMode.rapidEntry,
        seed: AttendanceStatus.present,
      );
      await typeQuery(tester, const Key('rapidEntryField'), 'sam');
      expect(find.text('Already here'), findsOneWidget);

      await tester.tap(find.byKey(const Key('fastMarkingResult_sam')));
      await tester.pumpAndSettle();
      expect(await savedStatus(h.sessions, 'sam'), AttendanceStatus.absent);
    });

    testWidgets('undo restores the status the person had before the mark',
        (tester) async {
      final h = await pumpMode(tester, MarkingMode.rapidEntry);
      await typeQuery(tester, const Key('rapidEntryField'), 'duc');
      await tester.tap(find.byKey(const Key('fastMarkingResult_duc')));
      await tester.pumpAndSettle();
      expect(await savedStatus(h.sessions, 'duc'), AttendanceStatus.present);

      await tester.tap(find.byKey(const Key('fastMarkingUndo_duc')));
      await tester.pumpAndSettle();
      expect(await savedStatus(h.sessions, 'duc'), AttendanceStatus.absent);
    });

    testWidgets('offers to add a guest when nobody matches', (tester) async {
      await pumpMode(tester, MarkingMode.rapidEntry);
      await typeQuery(tester, const Key('rapidEntryField'), 'zzzz');
      expect(find.byKey(const Key('fastMarkingAddGuest')), findsOneWidget);

      await tester.tap(find.byKey(const Key('fastMarkingAddGuest')));
      await tester.pumpAndSettle();
      expect(find.text('Add Person'), findsOneWidget);
    });

    testWidgets('the clear button empties the query', (tester) async {
      await pumpMode(tester, MarkingMode.rapidEntry);
      await typeQuery(tester, const Key('rapidEntryField'), 'ngu');
      await tester.tap(find.byKey(const Key('fastMarkingClear')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fastMarkingResult_an')), findsNothing);
    });
  });

  group('likely here', () {
    testWidgets('orders the grid by recent attendance, most frequent first',
        (tester) async {
      await pumpMode(tester, MarkingMode.likelyHere, withHistory: true);

      final chips = tester
          .widgetList<Widget>(
            find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith(
                        'likelyHereChip_',
                      ),
            ),
          )
          .map((w) => (w.key! as ValueKey<String>).value)
          .toList();
      // Duc attended all four, Bao half, An none, Sam has no history.
      expect(chips.take(3).toList(), [
        'likelyHereChip_duc',
        'likelyHereChip_bao',
        'likelyHereChip_an',
      ]);
    });

    testWidgets('tapping a chip marks that person present', (tester) async {
      final h = await pumpMode(tester, MarkingMode.likelyHere);
      await tester.tap(find.byKey(const Key('likelyHereChip_bao')));
      await tester.pumpAndSettle();

      expect(await savedStatus(h.sessions, 'bao'), AttendanceStatus.present);
    });

    testWidgets('tapping a marked chip unmarks it', (tester) async {
      final h = await pumpMode(tester, MarkingMode.likelyHere);
      await tester.tap(find.byKey(const Key('likelyHereChip_bao')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('likelyHereChip_bao')));
      await tester.pumpAndSettle();

      expect(await savedStatus(h.sessions, 'bao'), AttendanceStatus.absent);
    });

    testWidgets('the remaining count drops as people are marked',
        (tester) async {
      await pumpMode(tester, MarkingMode.likelyHere);
      expect(find.text('4 left · most frequent first'), findsOneWidget);

      await tester.tap(find.byKey(const Key('likelyHereChip_bao')));
      await tester.pumpAndSettle();
      expect(find.text('3 left · most frequent first'), findsOneWidget);
    });

    testWidgets('search hands off to rapid entry and back', (tester) async {
      await pumpMode(tester, MarkingMode.likelyHere);
      await tester.tap(find.byKey(const Key('likelyHereSearch')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rapidEntryField')), findsOneWidget);

      await tester.tap(find.byKey(const Key('rapidEntryBack')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('likelyHereChip_an')), findsOneWidget);
    });
  });

  group('households', () {
    testWidgets('search returns a household card', (tester) async {
      await pumpMode(tester, MarkingMode.households);
      await typeQuery(tester, const Key('householdsField'), 'nguyen');

      expect(find.byKey(const Key('householdCard_f-nguyen')), findsOneWidget);
      expect(find.text('Mark all 3 present'), findsOneWidget);
    });

    testWidgets('one button marks the whole family present', (tester) async {
      final h = await pumpMode(tester, MarkingMode.households);
      await typeQuery(tester, const Key('householdsField'), 'nguyen');
      await tester.tap(find.byKey(const Key('householdMarkAll_f-nguyen')));
      await tester.pumpAndSettle();

      for (final id in ['an', 'duc', 'bao']) {
        expect(await savedStatus(h.sessions, id), AttendanceStatus.present);
      }
    });

    testWidgets('a member can be dropped back out of a marked household',
        (tester) async {
      final h = await pumpMode(
        tester,
        MarkingMode.households,
        seed: AttendanceStatus.present,
      );
      await typeQuery(tester, const Key('householdsField'), 'nguyen');
      await tester.tap(find.byKey(const Key('householdMember_bao')));
      await tester.pumpAndSettle();

      expect(await savedStatus(h.sessions, 'bao'), AttendanceStatus.absent);
      expect(await savedStatus(h.sessions, 'an'), AttendanceStatus.present);
    });

    testWidgets('matches a household through one of its members',
        (tester) async {
      await pumpMode(tester, MarkingMode.households);
      await typeQuery(tester, const Key('householdsField'), 'duc');
      expect(find.byKey(const Key('householdCard_f-nguyen')), findsOneWidget);
    });

    testWidgets('an auto-singleton household renders as a plain row',
        (tester) async {
      await pumpMode(tester, MarkingMode.households);
      await typeQuery(tester, const Key('householdsField'), 'okafor');

      expect(find.byKey(const Key('householdCard_f-okafor')), findsNothing);
      expect(find.byKey(const Key('fastMarkingResult_sam')), findsOneWidget);
    });

    testWidgets('offers to add a guest when nothing matches', (tester) async {
      await pumpMode(tester, MarkingMode.households);
      await typeQuery(tester, const Key('householdsField'), 'zzzz');
      expect(find.byKey(const Key('fastMarkingAddGuest')), findsOneWidget);
    });
  });

  group('initials pad', () {
    testWidgets('shows no results until a first initial is picked',
        (tester) async {
      await pumpMode(tester, MarkingMode.initialsPad);
      expect(find.byKey(const Key('fastMarkingResult_an')), findsNothing);
    });

    testWidgets('one initial narrows the roster', (tester) async {
      await pumpMode(tester, MarkingMode.initialsPad);
      await tester.tap(find.byKey(const Key('initialsKey_A')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fastMarkingResult_an')), findsOneWidget);
      expect(find.byKey(const Key('fastMarkingResult_duc')), findsNothing);
    });

    testWidgets('a second initial narrows it further', (tester) async {
      await pumpMode(tester, MarkingMode.initialsPad);
      await tester.tap(find.byKey(const Key('initialsKey_B')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('initialsKey_N')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fastMarkingResult_bao')), findsOneWidget);
      expect(find.byKey(const Key('fastMarkingResult_an')), findsNothing);
    });

    testWidgets('letters nobody matches are not tappable', (tester) async {
      await pumpMode(tester, MarkingMode.initialsPad);
      await tester.tap(find.byKey(const Key('initialsKey_Q')));
      await tester.pumpAndSettle();

      // Q was inert, so the pad is still at the first stage.
      expect(find.text('Pick a first-name initial'), findsOneWidget);
    });

    testWidgets('a letter goes dark once its last match is marked',
        (tester) async {
      await pumpMode(tester, MarkingMode.initialsPad);
      await tester.tap(find.byKey(const Key('initialsKey_S')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fastMarkingResult_sam')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('initialsKey_S')));
      await tester.pumpAndSettle();
      expect(find.text('Pick a first-name initial'), findsOneWidget);
    });

    testWidgets('tapping a result marks that person present', (tester) async {
      final h = await pumpMode(tester, MarkingMode.initialsPad);
      await tester.tap(find.byKey(const Key('initialsKey_D')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fastMarkingResult_duc')));
      await tester.pumpAndSettle();

      expect(await savedStatus(h.sessions, 'duc'), AttendanceStatus.present);
    });

    testWidgets('marking resets the pad for the next person', (tester) async {
      await pumpMode(tester, MarkingMode.initialsPad);
      await tester.tap(find.byKey(const Key('initialsKey_D')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fastMarkingResult_duc')));
      await tester.pumpAndSettle();

      expect(find.text('Pick a first-name initial'), findsOneWidget);
    });

    testWidgets('backspace steps back one initial', (tester) async {
      await pumpMode(tester, MarkingMode.initialsPad);
      await tester.tap(find.byKey(const Key('initialsKey_B')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('initialsKey_N')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('initialsKey_back')));
      await tester.pumpAndSettle();
      expect(find.text('Now a surname initial'), findsOneWidget);
    });

    testWidgets('clearing the first chip returns to the full pad',
        (tester) async {
      await pumpMode(tester, MarkingMode.initialsPad);
      await tester.tap(find.byKey(const Key('initialsKey_B')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('initialsChip_first')));
      await tester.pumpAndSettle();
      expect(find.text('Pick a first-name initial'), findsOneWidget);
    });

    testWidgets('undo restores the previous status', (tester) async {
      final h = await pumpMode(tester, MarkingMode.initialsPad);
      await tester.tap(find.byKey(const Key('initialsKey_D')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fastMarkingResult_duc')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('fastMarkingUndo_duc')));
      await tester.pumpAndSettle();
      expect(await savedStatus(h.sessions, 'duc'), AttendanceStatus.absent);
    });
  });
}
