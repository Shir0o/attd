import 'package:attendance_tracker/core/design/app_theme.dart';
import 'package:attendance_tracker/core/design/widgets/conv_widgets.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_start_mode.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/marking_mode.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/presentation/add_guest_sheet.dart';
import 'package:attendance_tracker/features/attendance/presentation/attendance_deck_page.dart';
import 'package:attendance_tracker/features/attendance/presentation/fast_marking/fast_marking_shared.dart';
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

Session _session({
  AttendanceStatus seed = AttendanceStatus.absent,
  List<Member>? members,
}) {
  final at = DateTime(2026, 3, 1);
  return Session(
    id: 'current',
    title: 'Sunday Service',
    sessionDate: at,
    createdAt: at,
    updatedAt: at,
    createdBy: 'User',
    records: [
      for (final m in (members ?? _roster))
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
  AttendanceStartMode? startMode,
  List<Family>? families,
  bool disableAnimations = true,
  ThemeData? theme,
}) async {
  // Mirrors the hub: anything but an all-absent start opens the confirm List.
  final opensOnList =
      startMode != null && startMode != AttendanceStartMode.allAbsent;
  final sessions = MockSessionRepository();
  if (withHistory) sessions.setSessions(_history());
  final roster = families ?? [_nguyens, _okafor];
  final members = roster.expand((f) => f.members).toList();

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: AttendanceDeckPage(
        session: _session(seed: seed, members: members),
        members: members,
        families: roster,
        sessionRepository: sessions,
        attendanceRepository: MockAttendanceRepository(),
        eventRepository: MockEventRepository(),
        markingMode: mode,
        startMode: startMode,
        initialListMode: opensOnList,
        disableAnimations: disableAnimations,
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

    testWidgets('subtitle displays attendee last name for members without family',
        (tester) async {
      await pumpMode(tester, MarkingMode.rapidEntry);
      await typeQuery(tester, const Key('rapidEntryField'), 'sam');

      expect(find.byKey(const Key('fastMarkingResult_sam')), findsOneWidget);
      // Sam Okafor is an auto-singleton so familyName is null; subtitle should show 'Okafor'
      expect(find.text('Okafor'), findsOneWidget);
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
      expect(find.byKey(const Key('addSheetNameField')), findsOneWidget);
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

    testWidgets('the grid has no search: List owns searching', (tester) async {
      await pumpMode(tester, MarkingMode.likelyHere);
      expect(find.byKey(const Key('likelyHereSearch')), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('marking a chip does not push it to the end or shift other chips',
        (tester) async {
      await pumpMode(tester, MarkingMode.likelyHere, withHistory: true);

      List<String> getChipOrder() => tester
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

      final initialOrder = getChipOrder();
      // Tap the first chip
      await tester.tap(find.byKey(const Key('likelyHereChip_duc')));
      await tester.pumpAndSettle();

      // The order of chips must stay identical to prevent disorienting jumps
      expect(getChipOrder(), initialOrder);
    });

    testWidgets('unranked chips display attendee uppercase last name instead of NEW, and only given name in title',
        (tester) async {
      await pumpMode(tester, MarkingMode.likelyHere);
      // Roster without history: Sam Okafor and Nguyen family members
      expect(find.text('OKAFOR'), findsOneWidget);
      expect(find.text('NGUYEN'), findsNWidgets(3));
      expect(find.text('NEW'), findsNothing);

      // Given names shown in first row without duplicating the surname
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('An'), findsOneWidget);
      expect(find.text('Duc'), findsOneWidget);
      expect(find.text('Bao'), findsOneWidget);
      expect(find.text('Sam Okafor'), findsNothing);
      expect(find.text('An Nguyen'), findsNothing);
    });

    testWidgets('unranked chips for single-name member display full name and no duplicate surname subtitle',
        (tester) async {
      final singleMember = Member(id: 'cher', displayName: 'Cher');
      await pumpMode(
        tester,
        MarkingMode.likelyHere,
        families: [
          Family(
            id: 'f-cher',
            displayName: 'Cher',
            isAutoSingleton: true,
            members: [singleMember],
          ),
        ],
      );

      expect(find.text('Cher'), findsOneWidget);
      expect(find.text('CHER'), findsNothing);
    });

    testWidgets('the floating "Add someone" pill opens the add sheet',
        (tester) async {
      await pumpMode(tester, MarkingMode.likelyHere);
      expect(
        find.descendant(
          of: find.byKey(const Key('likelyHereAddGuest')),
          matching: find.text('Add someone'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('likelyHereAddGuest')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('addSheetNameField')), findsOneWidget);
    });

    testWidgets('the "Add someone" pill presses in when motion is on',
        (tester) async {
      await pumpMode(tester, MarkingMode.likelyHere, disableAnimations: false);
      final pill = find.byKey(const Key('likelyHereAddGuest'));
      final pressable = find.ancestor(
        of: pill,
        matching: find.byType(ConvPressable),
      );
      expect(pressable, findsOneWidget);
      final gesture = await tester.startGesture(tester.getCenter(pill));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      final scale = tester
          .widget<Transform>(
            find
                .descendant(of: pressable, matching: find.byType(Transform))
                .first,
          )
          .transform
          .entry(0, 0);
      expect(scale, closeTo(0.97, 0.001));
      await gesture.up();
      await tester.pumpAndSettle();
      // Releasing the press still opens the sheet.
      expect(find.byKey(const Key('addSheetNameField')), findsOneWidget);
    });

    testWidgets('the "Add someone" pill does not scale when motion is off',
        (tester) async {
      await pumpMode(tester, MarkingMode.likelyHere);
      expect(
        find.descendant(
          of: find.byType(ConvPressable),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
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

  group('every surface reports into the same session', () {
    for (final mode in [
      MarkingMode.rapidEntry,
      MarkingMode.likelyHere,
      MarkingMode.households,
      MarkingMode.initialsPad,
    ]) {
      testWidgets('${mode.name}: the header tally counts a mark made here',
          (tester) async {
        await pumpMode(tester, mode);
        expect(find.textContaining('4 left'), findsWidgets);

        switch (mode) {
          case MarkingMode.rapidEntry:
            await typeQuery(tester, const Key('rapidEntryField'), 'duc');
            await tester.tap(find.byKey(const Key('fastMarkingResult_duc')));
          case MarkingMode.likelyHere:
            await tester.tap(find.byKey(const Key('likelyHereChip_duc')));
          case MarkingMode.households:
            await typeQuery(tester, const Key('householdsField'), 'duc nguyen');
            await tester.tap(find.byKey(const Key('householdMember_duc')));
          case MarkingMode.initialsPad:
            await tester.tap(find.byKey(const Key('initialsKey_D')));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('fastMarkingResult_duc')));
          case MarkingMode.none:
            fail('not a fast surface');
        }
        await tester.pumpAndSettle();

        expect(find.textContaining('3 left'), findsWidgets);
      });

      testWidgets('${mode.name}: a guest can be added without leaving',
          (tester) async {
        await pumpMode(tester, mode);
        switch (mode) {
          case MarkingMode.rapidEntry:
            await typeQuery(tester, const Key('rapidEntryField'), 'zzzz');
            await tester.tap(find.byKey(const Key('fastMarkingAddGuest')));
          case MarkingMode.likelyHere:
            await tester.tap(find.byKey(const Key('likelyHereAddGuest')));
          case MarkingMode.households:
            await typeQuery(tester, const Key('householdsField'), 'zzzz');
            await tester.tap(find.byKey(const Key('fastMarkingAddGuest')));
          case MarkingMode.initialsPad:
            await tester.tap(find.byKey(const Key('initialsAddGuest')));
          case MarkingMode.none:
            fail('not a fast surface');
        }
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('addSheetNameField')), findsOneWidget);
      });
    }

    testWidgets('newly added attendee shows up in the Likely Here grid immediately',
        (tester) async {
      await pumpMode(tester, MarkingMode.likelyHere);
      expect(find.byKey(const Key('likelyHereChip_newbie')), findsNothing);

      await tester.tap(find.byKey(const Key('likelyHereAddGuest')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('addSheetNameField')),
        'Newbie Guest',
      );
      await tester.tap(find.byKey(const Key('addSheetAddToRoster')));
      await tester.pumpAndSettle();

      // Back on the grid: the new person's chip is there, already Here,
      // and a snackbar confirms it.
      expect(find.text('Newbie Guest'), findsOneWidget);
      expect(find.text('Newbie Guest added · Here'), findsOneWidget);
      expect(find.byKey(const Key('addSheetNameField')), findsNothing);
    });
  });

  group('under a confirm-mode session everyone starts present', () {
    testWidgets('the grid can flip somebody absent', (tester) async {
      final h = await pumpMode(
        tester,
        MarkingMode.likelyHere,
        seed: AttendanceStatus.present,
        startMode: AttendanceStartMode.allPresent,
      );
      // The confirm List owns the opening surface; the fast one is a segment.
      await tester.tap(find.text('Likely'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('likelyHereChip_bao')));
      await tester.pumpAndSettle();
      expect(await savedStatus(h.sessions, 'bao'), AttendanceStatus.absent);
    });

    testWidgets('a bulk-default session still opens on the confirm List',
        (tester) async {
      await pumpMode(
        tester,
        MarkingMode.likelyHere,
        seed: AttendanceStatus.present,
        startMode: AttendanceStartMode.allPresent,
      );
      expect(find.byKey(const Key('likelyHereChip_bao')), findsNothing);
      expect(find.text('Likely'), findsOneWidget);
    });

    testWidgets('the household button clears a family that is already here',
        (tester) async {
      final h = await pumpMode(
        tester,
        MarkingMode.households,
        seed: AttendanceStatus.present,
        startMode: AttendanceStartMode.allPresent,
      );
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();
      await typeQuery(tester, const Key('householdsField'), 'nguyen');

      expect(find.text('Clear all 3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('householdMarkAll_f-nguyen')));
      await tester.pumpAndSettle();

      for (final id in ['an', 'duc', 'bao']) {
        expect(await savedStatus(h.sessions, id), AttendanceStatus.absent);
      }
    });
  });

  group('undo covers both directions', () {
    testWidgets('an accidental un-mark can be taken back', (tester) async {
      final h = await pumpMode(
        tester,
        MarkingMode.rapidEntry,
        seed: AttendanceStatus.present,
      );
      await typeQuery(tester, const Key('rapidEntryField'), 'sam');
      await tester.tap(find.byKey(const Key('fastMarkingResult_sam')));
      await tester.pumpAndSettle();
      expect(await savedStatus(h.sessions, 'sam'), AttendanceStatus.absent);

      await tester.tap(find.byKey(const Key('fastMarkingUndo_sam')));
      await tester.pumpAndSettle();
      expect(await savedStatus(h.sessions, 'sam'), AttendanceStatus.present);
    });
  });

  group('search results explain themselves', () {
    testWidgets('the matched run of the name is highlighted', (tester) async {
      await pumpMode(tester, MarkingMode.rapidEntry);
      await typeQuery(tester, const Key('rapidEntryField'), 'ngu');

      final name = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('fastMarkingResult_an')),
          matching: find.byWidgetPredicate(
            (w) => w is Text && w.textSpan != null,
          ),
        ),
      );
      final spans = (name.textSpan! as TextSpan).children!.cast<TextSpan>();
      final highlighted = spans.singleWhere(
        (s) => s.style?.backgroundColor != null,
      );
      expect(highlighted.text, 'Ngu');
    });
  });

  group('every surface survives a real phone', () {
    // Regression: a 60pt grid tile fitted a one-line name on the desktop-sized
    // default test surface but overflowed on a phone, where "Regular Member 1"
    // wraps to two lines; the grid's own caption row overflowed there too.
    // Both shipped and only Firebase Test Lab caught them.
    final longRoster = [
      Family(
        id: 'f-long',
        displayName: 'Featherstonehaugh',
        members: [
          Member(id: 'r1', displayName: 'Regular Member 1'),
          Member(id: 'r2', displayName: 'Regular Member 2'),
          Member(id: 'r3', displayName: 'Bartholomew Featherstonehaugh'),
        ],
      ),
    ];

    for (final mode in [
      MarkingMode.rapidEntry,
      MarkingMode.likelyHere,
      MarkingMode.households,
      MarkingMode.initialsPad,
    ]) {
      testWidgets('${mode.name}: long names do not overflow at phone width',
          (tester) async {
        tester.view.physicalSize = const Size(822, 1782); // 411x891 logical
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);

        await pumpMode(tester, mode, families: longRoster);
        expect(tester.takeException(), isNull, reason: 'on entry');

        switch (mode) {
          case MarkingMode.rapidEntry:
            await typeQuery(tester, const Key('rapidEntryField'), 'regular');
          case MarkingMode.households:
            await typeQuery(tester, const Key('householdsField'), 'feather');
          case MarkingMode.initialsPad:
            await tester.tap(find.byKey(const Key('initialsKey_R')));
            await tester.pumpAndSettle();
          case MarkingMode.likelyHere:
          case MarkingMode.none:
            break;
        }
        expect(tester.takeException(), isNull, reason: 'with results showing');
      });
    }
  });

  group('the "Add someone" pill grows into the add sheet', () {
    final pill = find.byKey(const Key('likelyHereAddGuest'));
    final bounds = find.byKey(convMorphSheetBoundsKey);
    final nameField = find.byKey(const Key('addSheetNameField'));

    Future<void> pumpPhone(WidgetTester tester) async {
      tester.view.physicalSize = const Size(822, 1782); // 411x891 logical
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await pumpMode(tester, MarkingMode.likelyHere, disableAnimations: false);
    }

    bool pillShown(WidgetTester tester) => tester
        .widget<Visibility>(
          find.ancestor(of: pill, matching: find.byType(Visibility)).first,
        )
        .visible;

    bool nameFocused(WidgetTester tester) => tester
        .widget<EditableText>(
          find.descendant(of: nameField, matching: find.byType(EditableText)),
        )
        .focusNode
        .hasFocus;

    /// Opens the sheet from the pill and lets it form; returns the pill's rect
    /// and the formed sheet's.
    Future<({Rect pill, Rect sheet})> openFormed(WidgetTester tester) async {
      final pillRect = tester.getRect(pill);
      await tester.tap(pill);
      await tester.pumpAndSettle();
      return (pill: pillRect, sheet: tester.getRect(bounds));
    }

    void expectRectNear(Rect actual, Rect expected) {
      expect(actual.left, closeTo(expected.left, 1));
      expect(actual.top, closeTo(expected.top, 1));
      expect(actual.right, closeTo(expected.right, 1));
      expect(actual.bottom, closeTo(expected.bottom, 1));
    }

    testWidgets('starts at the pill and ends as the full-width sheet',
        (tester) async {
      await pumpPhone(tester);
      final pillRect = tester.getRect(pill);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;

      await tester.tap(pill);
      await tester.pump();
      expectRectNear(tester.getRect(bounds), pillRect);
      // Not the plain slide-up sheet.
      expect(find.byType(BottomSheet), findsNothing);

      await tester.pump(const Duration(milliseconds: 150));
      final mid = tester.getRect(bounds);
      expect(mid.left, inExclusiveRange(0, pillRect.left));
      expect(mid.top, lessThan(pillRect.top));
      expect(mid.width, inExclusiveRange(pillRect.width, screen.width));

      await tester.pumpAndSettle();
      final formed = tester.getRect(bounds);
      expect(formed.left, 0);
      expect(formed.width, screen.width);
      expect(formed.bottom, screen.height);
      expect(
        tester.getRect(find.byType(AddMemberSheet)),
        formed,
        reason: 'the content fills the formed bounds',
      );
    });

    testWidgets('the name field is focused only once the sheet has formed',
        (tester) async {
      await pumpPhone(tester);
      await tester.tap(pill);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(nameFocused(tester), isFalse);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(nameFocused(tester), isTrue);
    });

    testWidgets('the pill hides while the sheet is up', (tester) async {
      await pumpPhone(tester);
      expect(pillShown(tester), isTrue);
      await openFormed(tester);
      expect(pillShown(tester), isFalse);
    });

    testWidgets('a scrim tap collapses the sheet back into the pill',
        (tester) async {
      await pumpPhone(tester);
      final rects = await openFormed(tester);

      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final mid = tester.getRect(bounds);
      expect(mid.left, inExclusiveRange(rects.sheet.left, rects.pill.left));
      expect(mid.width, inExclusiveRange(rects.pill.width, rects.sheet.width));
      expect(pillShown(tester), isFalse, reason: 'still collapsing');

      // The last frame before the route goes has landed on the pill, so the
      // real pill takes over without a jump.
      var last = mid;
      while (bounds.evaluate().isNotEmpty) {
        last = tester.getRect(bounds);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expectRectNear(last, rects.pill);

      await tester.pumpAndSettle();
      expect(bounds, findsNothing);
      expect(nameField, findsNothing);
      expect(pillShown(tester), isTrue);
      expect(pill.hitTestable(), findsOneWidget);
    });

    testWidgets('system back collapses the sheet back into the pill',
        (tester) async {
      await pumpPhone(tester);
      final rects = await openFormed(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final mid = tester.getRect(bounds);
      expect(mid.width, inExclusiveRange(rects.pill.width, rects.sheet.width));

      await tester.pumpAndSettle();
      expect(nameField, findsNothing);
      expect(pillShown(tester), isTrue);
      // Still on the deck page: back closed only the sheet.
      expect(pill, findsOneWidget);
    });

    testWidgets('dragging down follows the finger and slides off the bottom',
        (tester) async {
      await pumpPhone(tester);
      final rects = await openFormed(tester);
      final handle = find.descendant(
        of: find.byType(AddMemberSheet),
        matching: find.text('Add someone'),
      );

      final gesture = await tester.startGesture(tester.getCenter(handle));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump(const Duration(milliseconds: 16));
      }
      final dragged = tester.getRect(bounds);
      expect(dragged.width, rects.sheet.width);
      expect(dragged.top, greaterThan(rects.sheet.top + 250));

      await gesture.up();
      // Every frame of the exit is the full-width sheet sliding down; it
      // never collapses toward the pill.
      var lastTop = dragged.top;
      while (bounds.evaluate().isNotEmpty) {
        final r = tester.getRect(bounds);
        expect(r.left, rects.sheet.left);
        expect(r.width, rects.sheet.width);
        expect(r.top, greaterThanOrEqualTo(lastTop));
        lastTop = r.top;
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(nameField, findsNothing);
      expect(pillShown(tester), isTrue);
    });

    testWidgets('a short drag springs back, then a cancel still collapses',
        (tester) async {
      await pumpPhone(tester);
      final rects = await openFormed(tester);
      final handle = find.descendant(
        of: find.byType(AddMemberSheet),
        matching: find.text('Add someone'),
      );

      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(bounds), rects.sheet);

      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getRect(bounds).width, lessThan(rects.sheet.width));
      await tester.pumpAndSettle();
      expect(pillShown(tester), isTrue);
    });

    testWidgets('a fling dismisses the sheet', (tester) async {
      await pumpPhone(tester);
      await openFormed(tester);
      await tester.fling(
        find.descendant(
          of: find.byType(AddMemberSheet),
          matching: find.text('Add someone'),
        ),
        const Offset(0, 120),
        1500,
      );
      await tester.pumpAndSettle();
      expect(nameField, findsNothing);
      expect(pillShown(tester), isTrue);
    });

    testWidgets('submitting slides the sheet down and still adds the person',
        (tester) async {
      await pumpPhone(tester);
      final rects = await openFormed(tester);
      await tester.enterText(nameField, 'Newbie Guest');
      await tester.tap(find.byKey(const Key('addSheetAddToRoster')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.getRect(bounds);
      expect(mid.width, rects.sheet.width);
      expect(mid.top, greaterThan(rects.sheet.top));

      await tester.pumpAndSettle();
      expect(nameField, findsNothing);
      expect(find.text('Newbie Guest'), findsOneWidget);
      expect(find.text('Newbie Guest added · Here'), findsOneWidget);
      expect(pillShown(tester), isTrue);
    });

    testWidgets('with the system "Remove animations" setting it is the plain '
        'sheet, focused at once', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpPhone(tester);
      await tester.tap(pill);
      await tester.pump();
      await tester.pump();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(bounds, findsNothing);
      expect(nameFocused(tester), isTrue);
    });

    testWidgets('with the test flag it is the plain sheet, focused at once',
        (tester) async {
      await pumpMode(tester, MarkingMode.likelyHere);
      await tester.tap(pill);
      await tester.pump();
      await tester.pump();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(bounds, findsNothing);
      expect(nameFocused(tester), isTrue);
    });

    testWidgets("the deck's Add guest button keeps the plain sheet",
        (tester) async {
      await pumpMode(tester, MarkingMode.none, disableAnimations: false);
      await tester.tap(find.byKey(const Key('deckAddGuestButton')));
      await tester.pump();
      await tester.pump();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(bounds, findsNothing);
      expect(nameFocused(tester), isTrue);
    });
  });

  group('marking feedback (#222 M4, M5)', () {
    double scaleIn(WidgetTester tester, Finder of) => tester
        .widget<Transform>(
          find.descendant(of: of, matching: find.byType(Transform)).first,
        )
        .transform
        .entry(0, 0);

    testWidgets('a Likely tile pops on press and the mark still lands',
        (tester) async {
      final h = await pumpMode(
        tester,
        MarkingMode.likelyHere,
        disableAnimations: false,
      );
      final chip = find.byKey(const Key('likelyHereChip_duc'));
      final gesture = await tester.startGesture(tester.getCenter(chip));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(scaleIn(tester, chip), lessThan(1));
      expect(find.textContaining('4 left'), findsWidgets,
          reason: 'nothing is marked until release');

      await gesture.up();
      await tester.pumpAndSettle();
      expect(scaleIn(tester, chip), closeTo(1, 0.001));
      expect(await savedStatus(h.sessions, 'duc'), AttendanceStatus.present);
    });

    testWidgets('a pad key pops on press and still types its letter',
        (tester) async {
      await pumpMode(tester, MarkingMode.initialsPad, disableAnimations: false);
      final key = find.byKey(const Key('initialsKey_D'));

      final gesture = await tester.startGesture(tester.getCenter(key));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(scaleIn(tester, key), lessThan(1));

      // Cancelling springs back without typing the letter.
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(scaleIn(tester, key), closeTo(1, 0.001));
      expect(find.byKey(const Key('initialsChip_first')), findsNothing);

      await tester.tap(key);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('initialsChip_first')), findsOneWidget);
    });

    testWidgets('icon keys and unmatched letters do not pop', (tester) async {
      await pumpMode(tester, MarkingMode.initialsPad, disableAnimations: false);
      // Backspace and reset are icon keys, and a letter with no match is
      // disabled: none of them scale.
      for (final key in ['back', 'reset', 'Z']) {
        expect(
          find.descendant(
            of: find.byKey(Key('initialsKey_$key')),
            matching: find.byType(Transform),
          ),
          findsNothing,
          reason: key,
        );
      }
    });

    testWidgets('an initials chip no longer scales and still clears',
        (tester) async {
      await pumpMode(tester, MarkingMode.initialsPad, disableAnimations: false);
      await tester.tap(find.byKey(const Key('initialsKey_D')));
      await tester.pumpAndSettle();
      final chip = find.byKey(const Key('initialsChip_first'));

      final gesture = await tester.startGesture(tester.getCenter(chip));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(
        find.descendant(of: chip, matching: find.byType(Transform)),
        findsNothing,
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(chip, findsNothing);
      expect(find.text('Pick a first-name initial'), findsOneWidget);
    });

    testWidgets('list rows do not pop', (tester) async {
      await pumpMode(tester, MarkingMode.initialsPad, disableAnimations: false);
      await tester.tap(find.byKey(const Key('initialsKey_D')));
      await tester.pumpAndSettle();
      expect(find.byType(FastMarkingRow), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(FastMarkingRow),
          matching: find.byType(ConvPressable),
        ),
        findsNothing,
      );
    });

    testWidgets('the tally rolls to the new counts', (tester) async {
      await pumpMode(tester, MarkingMode.likelyHere, disableAnimations: false);
      final tail = find.byKey(const Key('headerTallyTail'));
      final present = find.byKey(const Key('headerTallyPresent'));

      await tester.tap(find.byKey(const Key('likelyHereChip_duc')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      // Mid-roll the old and the new digit are both on their way.
      for (final digit in ['4', '3']) {
        expect(
          find.descendant(of: tail, matching: find.text(digit)),
          findsOneWidget,
        );
      }

      await tester.pumpAndSettle();
      expect(
        find.descendant(of: tail, matching: find.text('3 left')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: present, matching: find.text('1')),
        findsOneWidget,
      );
    });

    testWidgets('the progress fill eases instead of jumping', (tester) async {
      await pumpMode(tester, MarkingMode.likelyHere, disableAnimations: false);
      final fill = find.descendant(
        of: find.byKey(const Key('headerProgressPresent')),
        matching: find.byType(ColoredBox),
      );
      final track = tester.getSize(
        find.ancestor(of: fill, matching: find.byType(Stack)).first,
      );
      expect(tester.getSize(fill).width, 0);

      await tester.tap(find.byKey(const Key('likelyHereChip_duc')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        tester.getSize(fill).width,
        inExclusiveRange(0, track.width / 4),
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getSize(fill).width, closeTo(track.width / 4, 0.01));
      expect(tester.getSize(fill).height, track.height);
    });

    testWidgets('confirm mode eases both tones of the bar', (tester) async {
      await pumpMode(
        tester,
        MarkingMode.likelyHere,
        seed: AttendanceStatus.present,
        startMode: AttendanceStartMode.allPresent,
        disableAnimations: false,
      );
      await tester.tap(find.text('Likely'));
      await tester.pumpAndSettle();
      Finder fill(String key) => find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(ColoredBox),
          );
      final width = tester.getSize(fill('headerProgressPresent')).width;
      expect(tester.getSize(fill('headerProgressAbsent')).width, width);

      await tester.tap(find.byKey(const Key('likelyHereChip_bao')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        tester.getSize(fill('headerProgressPresent')).width,
        inExclusiveRange(width * 3 / 4, width),
      );

      await tester.pumpAndSettle();
      expect(
        tester.getSize(fill('headerProgressPresent')).width,
        closeTo(width * 3 / 4, 0.01),
      );
      expect(tester.getSize(fill('headerProgressAbsent')).width, width);
      expect(find.text('1 changed'), findsOneWidget);
    });

    testWidgets('with motion off the tally and the bar snap', (tester) async {
      await pumpMode(tester, MarkingMode.likelyHere);
      final fill = find.descendant(
        of: find.byKey(const Key('headerProgressPresent')),
        matching: find.byType(ColoredBox),
      );
      final track = tester.getSize(
        find.ancestor(of: fill, matching: find.byType(Stack)).first,
      );

      await tester.tap(find.byKey(const Key('likelyHereChip_duc')));
      await tester.pump();
      expect(find.text('3 left'), findsOneWidget);
      expect(tester.getSize(fill).width, closeTo(track.width / 4, 0.01));
    });
  });

  group('a submit from the add sheet lands where the person went (#222 M3)',
      () {
    final pill = find.byKey(const Key('likelyHereAddGuest'));
    final nameField = find.byKey(const Key('addSheetNameField'));
    final shuttle = find.byKey(convLandingShuttleKey);
    final grid = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(Scrollable),
    );

    /// Forty people with no history: a newcomer sorts last, far below the
    /// fold.
    final bigRoster = [
      Family(
        id: 'f-big',
        displayName: 'Big',
        isAutoSingleton: true,
        members: [
          for (var i = 0; i < 40; i++)
            Member(id: 'm$i', displayName: 'Member ${i.toString().padLeft(2, '0')}'),
        ],
      ),
    ];

    Future<void> pumpPhone(
      WidgetTester tester, {
      List<Family>? families,
      bool disableAnimations = false,
    }) async {
      tester.view.physicalSize = const Size(822, 1782); // 411x891 logical
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await pumpMode(
        tester,
        MarkingMode.likelyHere,
        families: families,
        disableAnimations: disableAnimations,
        // The app's floating snackbar, which the flight lands on.
        theme: AppTheme.lightTheme(),
      );
    }

    /// The tile showing [name]. The test directory cannot create members, so
    /// a newcomer is added id-less and keyed `likelyHereChip_`.
    Finder tileOf(String name) => find.ancestor(
          of: find.text(name),
          matching: find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('likelyHereChip_'),
          ),
        );

    Finder snackBarOf(String name) => find
        .ancestor(
          of: find.text('$name added · Here'),
          matching: find.byType(Material),
        )
        .first;

    void expectRectNear(Rect actual, Rect expected) {
      expect(actual.left, closeTo(expected.left, 1));
      expect(actual.top, closeTo(expected.top, 1));
      expect(actual.right, closeTo(expected.right, 1));
      expect(actual.bottom, closeTo(expected.bottom, 1));
    }

    /// Submits [name] with [control], optionally while [earlierSnackBar] is
    /// up, and returns the shuttle's first and
    /// last rects (empty when it never showed).
    Future<List<Rect>> submit(
      WidgetTester tester,
      String name,
      Key control, {
      String? earlierSnackBar,
    }) async {
      await tester.tap(pill);
      await tester.pumpAndSettle();
      await tester.enterText(nameField, name);
      if (earlierSnackBar != null) {
        ScaffoldMessenger.of(tester.element(grid))
            .showSnackBar(SnackBar(content: Text(earlierSnackBar)));
      }
      await tester.pumpAndSettle();
      final rects = <Rect>[];
      await tester.tap(find.byKey(control));
      await tester.pump();
      for (var i = 0; i < 60; i++) {
        if (shuttle.evaluate().isNotEmpty) rects.add(tester.getRect(shuttle));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      return rects;
    }

    testWidgets('Add to roster flies from the pill to the visible new tile',
        (tester) async {
      await pumpPhone(tester);
      await tester.tap(pill);
      await tester.pumpAndSettle();
      await tester.enterText(nameField, 'Newbie Guest');
      final from = tester.getRect(find.byKey(const Key('addSheetAddToRoster')));
      await tester.tap(find.byKey(const Key('addSheetAddToRoster')));
      await tester.pump();
      expectRectNear(tester.getRect(shuttle), from);
      expect(
        find.descendant(of: shuttle, matching: find.text('Add to roster')),
        findsOneWidget,
      );

      var last = from;
      var frames = 0;
      while (shuttle.evaluate().isNotEmpty) {
        last = tester.getRect(shuttle);
        await tester.pump(const Duration(milliseconds: 16));
        expect(++frames, lessThan(60), reason: 'the flight ends');
      }
      expectRectNear(last, tester.getRect(tileOf('Newbie Guest')));
      expect(find.text('Newbie Guest added · Here'), findsOneWidget);
    });

    testWidgets(
        'Mark as guest lands on the guest tile: a Guest Mark shows on the '
        'grid', (tester) async {
      await pumpPhone(tester);
      final rects =
          await submit(tester, 'Walk In', const Key('addSheetMarkGuest'));
      expect(tileOf('Walk In'), findsOneWidget);
      expect(rects, isNotEmpty);
      expectRectNear(rects.last, tester.getRect(tileOf('Walk In')));
    });

    testWidgets('picking a directory member flies their row to their tile',
        (tester) async {
      await pumpPhone(tester);
      await tester.tap(pill);
      await tester.pumpAndSettle();
      await tester.enterText(nameField, 'Duc');
      await tester.pumpAndSettle();
      final row = find.byKey(const Key('addSheetSuggestion_duc'));
      final from = tester.getRect(row);
      await tester.tap(row);
      await tester.pump();
      expectRectNear(tester.getRect(shuttle), from);
      var last = from;
      while (shuttle.evaluate().isNotEmpty) {
        last = tester.getRect(shuttle);
        await tester.pump(const Duration(milliseconds: 16));
      }
      expectRectNear(
        last,
        tester.getRect(find.byKey(const Key('likelyHereChip_duc'))),
      );
    });

    testWidgets(
        'an off-screen tile lands in the snackbar and the grid stays put',
        (tester) async {
      await pumpPhone(tester, families: bigRoster);
      await tester.drag(grid, const Offset(0, -120));
      await tester.pumpAndSettle();
      final offset = tester.state<ScrollableState>(grid).position.pixels;
      expect(offset, greaterThan(0));

      final rects =
          await submit(tester, 'Zed Zulu', const Key('addSheetAddToRoster'));
      expect(rects, isNotEmpty);
      expectRectNear(rects.last, tester.getRect(snackBarOf('Zed Zulu')));
      expect(tester.state<ScrollableState>(grid).position.pixels, offset);
      expect(tileOf('Zed Zulu').hitTestable(), findsNothing);
    });

    testWidgets('a snackbar still queued behind the last one is still found',
        (tester) async {
      await pumpPhone(tester, families: bigRoster);
      final rects = await submit(
        tester,
        'Zed Zulu',
        const Key('addSheetAddToRoster'),
        earlierSnackBar: 'Marked 40 members present.',
      );
      expect(rects, isNotEmpty);
      expectRectNear(rects.last, tester.getRect(snackBarOf('Zed Zulu')));
    });

    testWidgets('cancelling the sheet flies nothing', (tester) async {
      await pumpPhone(tester);
      await tester.tap(pill);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(shuttle, findsNothing);
      }
    });

    testWidgets('with motion off nothing flies', (tester) async {
      await pumpPhone(tester, disableAnimations: true);
      final rects =
          await submit(tester, 'Newbie Guest', const Key('addSheetAddToRoster'));
      expect(rects, isEmpty);
      expect(find.text('Newbie Guest added · Here'), findsOneWidget);
    });

    testWidgets("the deck's Add guest button flies nothing", (tester) async {
      await pumpMode(tester, MarkingMode.none, disableAnimations: false);
      await tester.tap(find.byKey(const Key('deckAddGuestButton')));
      await tester.pumpAndSettle();
      await tester.enterText(nameField, 'Newbie Guest');
      await tester.tap(find.byKey(const Key('addSheetAddToRoster')));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(shuttle, findsNothing);
      }
      await tester.pumpAndSettle();
      expect(find.text('Newbie Guest added · Here'), findsOneWidget);
    });
  });
}
