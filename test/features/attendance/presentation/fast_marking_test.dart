import 'package:attendance_tracker/core/design/app_colors.dart';
import 'package:attendance_tracker/core/design/app_theme.dart';
import 'package:attendance_tracker/core/design/widgets/conv_widgets.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/presentation/add_guest_sheet.dart';
import 'package:attendance_tracker/features/attendance/presentation/attendance_deck_page.dart';
import 'package:attendance_tracker/features/attendance/presentation/done_progress_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
          recordedBy: 'User',
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

/// Pumps the real session page, which is always the name grid.
Future<Harness> pumpPage(
  WidgetTester tester, {
  AttendanceStatus seed = AttendanceStatus.absent,
  bool withHistory = false,
  List<Family>? families,
  bool disableAnimations = true,
  ThemeData? theme,
}) async {
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
        sessionRepository: sessions,
        attendanceRepository: MockAttendanceRepository(),
        eventRepository: MockEventRepository(),
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

void main() {
  group('the page always opens on the grid', () {
    testWidgets('it is the grid, with no fast-marking surface', (tester) async {
      await pumpPage(tester);
      expect(find.byKey(const Key('likelyHereChip_an')), findsOneWidget);
      expect(find.byKey(const Key('rapidEntryField')), findsNothing);
      expect(find.byKey(const Key('householdsField')), findsNothing);
      expect(find.byKey(const Key('initialsKey_D')), findsNothing);
    });

    testWidgets('there is no Deck/List/fast switch', (tester) async {
      await pumpPage(tester);
      expect(find.byKey(const Key('deckListModeToggle')), findsNothing);
      expect(find.byType(ConvSegmented), findsNothing);
      expect(find.text('Deck'), findsNothing);
      expect(find.text('List'), findsNothing);
    });

    testWidgets('the grid shows one "N left" and no "Likely here" heading',
        (tester) async {
      await pumpPage(tester);
      expect(find.textContaining('left'), findsOneWidget);
      expect(find.text('4 left'), findsOneWidget);
      expect(find.byKey(const Key('likelyHereRemaining')), findsNothing);
      expect(find.text('LIKELY HERE'), findsNothing);
      expect(find.text('Likely here'), findsNothing);
    });
  });

  group('likely here', () {
    List<String> chipOrder(WidgetTester tester) => tester
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

    testWidgets('orders the grid alphabetically, ignoring attendance history',
        (tester) async {
      await pumpPage(tester, withHistory: true);

      // Duc attended all four and An none, but the grid is A to Z.
      expect(chipOrder(tester), [
        'likelyHereChip_an',
        'likelyHereChip_bao',
        'likelyHereChip_duc',
        'likelyHereChip_sam',
      ]);
    });

    testWidgets('alphabetical order ignores case', (tester) async {
      await pumpPage(tester,
        families: [
          Family(
            id: 'f-mixed',
            displayName: 'Mixed',
            isAutoSingleton: true,
            members: [
              Member(id: 'zed', displayName: 'Zed Ash'),
              Member(id: 'amy', displayName: 'amy Lowe'),
              Member(id: 'ben', displayName: 'Ben Cole'),
            ],
          ),
        ],
      );

      expect(chipOrder(tester), [
        'likelyHereChip_amy',
        'likelyHereChip_ben',
        'likelyHereChip_zed',
      ]);
    });

    testWidgets('a guest added this session sorts in with everyone',
        (tester) async {
      await pumpPage(tester);
      await tester.tap(find.byKey(const Key('likelyHereAddGuest')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('addSheetNameField')),
        'Cara Visitor',
      );
      await tester.tap(find.byKey(const Key('addSheetMarkGuest')));
      await tester.pumpAndSettle();

      expect(chipOrder(tester), [
        'likelyHereChip_an',
        'likelyHereChip_bao',
        'likelyHereChip_visitor_Cara Visitor',
        'likelyHereChip_duc',
        'likelyHereChip_sam',
      ]);
    });

    testWidgets('tapping a chip marks that person present', (tester) async {
      final h = await pumpPage(tester);
      await tester.tap(find.byKey(const Key('likelyHereChip_bao')));
      await tester.pumpAndSettle();

      expect(await savedStatus(h.sessions, 'bao'), AttendanceStatus.present);
    });

    testWidgets('tapping a marked chip unmarks it', (tester) async {
      final h = await pumpPage(tester);
      await tester.tap(find.byKey(const Key('likelyHereChip_bao')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('likelyHereChip_bao')));
      await tester.pumpAndSettle();

      expect(await savedStatus(h.sessions, 'bao'), AttendanceStatus.absent);
    });

    testWidgets('the remaining count drops as people are marked',
        (tester) async {
      await pumpPage(tester);
      expect(find.text('4 left'), findsOneWidget);

      await tester.tap(find.byKey(const Key('likelyHereChip_bao')));
      await tester.pumpAndSettle();
      expect(find.text('3 left'), findsOneWidget);
    });

    testWidgets(
        'a marked tile keeps its text, drops the "Here" label, and reads as '
        'selected', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPage(tester);
      const chip = Key('likelyHereChip_bao');
      expect(
        tester.getSemantics(find.byKey(chip)),
        containsSemantics(label: 'Bao Nguyen', isSelected: false),
      );

      await tester.tap(find.byKey(chip));
      await tester.pumpAndSettle();

      final tile = find.byKey(chip);
      expect(find.descendant(of: tile, matching: find.text('Bao')),
          findsOneWidget);
      expect(find.descendant(of: tile, matching: find.text('NGUYEN')),
          findsOneWidget);
      expect(find.descendant(of: tile, matching: find.text('Here')),
          findsNothing);
      expect(find.descendant(of: tile, matching: find.byIcon(Icons.check_rounded)),
          findsNothing);
      expect(
        tester.getSemantics(tile),
        containsSemantics(
          label: 'Bao Nguyen',
          isSelected: true,
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    for (final dark in [false, true]) {
      testWidgets(
          'the given name is the headline in full-strength ink '
          '(${dark ? 'dark' : 'light'})', (tester) async {
        await pumpPage(tester,
          theme: dark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
        );
        final ink =
            dark ? ConvocationColors.dark.ink : ConvocationColors.light.ink;
        final name = tester.widget<Text>(find.text('Bao'));
        final surname = tester.widget<Text>(find.text('NGUYEN').first);
        expect(name.style!.color, ink);
        expect(name.style!.fontSize, greaterThanOrEqualTo(16));
        expect(name.style!.fontWeight, FontWeight.w600);
        expect(surname.style!.fontSize, lessThan(name.style!.fontSize!));
        expect(surname.overflow, TextOverflow.ellipsis);
      });
    }

    testWidgets('a long given name is never truncated', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpPage(tester,
        families: [
          Family(
            id: 'f-long',
            displayName: 'Long',
            isAutoSingleton: true,
            members: [
              Member(
                id: 'long',
                displayName: 'Maximiliana-Alexandrina Featherstonehaugh',
              ),
              Member(id: 'kai', displayName: 'Kai Wong'),
            ],
          ),
        ],
      );

      const given = 'Maximiliana-Alexandrina';
      final text = tester.widget<Text>(find.text(given));
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(text.maxLines, isNull);
      expect(text.softWrap, isTrue);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(given));
      expect(paragraph.didExceedMaxLines, isFalse);
      // It wrapped rather than shrinking past legibility, and stays inside its
      // tile.
      final lineHeight = paragraph.text.style!.fontSize!;
      expect(paragraph.size.height, greaterThan(lineHeight * 1.5));
      final tile = tester.getRect(find.byKey(const Key('likelyHereChip_long')));
      final name = tester.getRect(find.text(given));
      expect(tile.contains(name.topLeft), isTrue);
      expect(tile.contains(name.bottomRight - const Offset(0.5, 0.5)), isTrue);

      // A short name keeps the full headline size on one line.
      final kai = tester.widget<Text>(find.text('Kai'));
      expect(kai.maxLines, 1);
      expect(kai.style!.fontSize, 16);
    });

    group('letter strip', () {
      // Two people for each of A to T; nobody starts with U to Z.
      const letters = 'ABCDEFGHIJKLMNOPQRST';
      final crowd = [
        Family(
          id: 'f-crowd',
          displayName: 'Crowd',
          isAutoSingleton: true,
          members: [
            for (final l in letters.split(''))
              for (var i = 0; i < 2; i++)
                Member(id: '$l$i', displayName: '${l}ra$i Smith'),
          ],
        ),
      ];
      const strip = Key('likelyHereLetterStrip');
      Key letter(String l) => Key('likelyHereLetter_$l');
      final grid = find.byType(GridView);

      testWidgets('lists only the letters some name starts with',
          (tester) async {
        await pumpPage(tester, families: crowd);
        expect(find.byKey(strip), findsOneWidget);
        for (final l in letters.split('')) {
          expect(find.byKey(letter(l)), findsOneWidget);
        }
        expect(find.byKey(letter('U')), findsNothing);
        expect(find.byKey(letter('Z')), findsNothing);
        // Sized to fit: the last letter is laid out inside the strip.
        final stripRect = tester.getRect(find.byKey(strip));
        expect(stripRect.contains(tester.getCenter(find.byKey(letter('T')))),
            isTrue);
      });

      testWidgets('touching a letter jumps its first tile to the top',
          (tester) async {
        await pumpPage(tester, families: crowd);
        final top = tester.getRect(grid).top;

        final gesture =
            await tester.startGesture(tester.getCenter(find.byKey(letter('K'))));
        await tester.pump();
        // A big letter bubble shows while the finger is down.
        expect(
          find.descendant(
            of: find.byKey(const Key('likelyHereLetterBubble')),
            matching: find.text('K'),
          ),
          findsOneWidget,
        );
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('likelyHereLetterBubble')), findsNothing);
        expect(tester.getRect(find.byKey(const Key('likelyHereChip_K0'))).top,
            closeTo(top, 0.5));
        // It jumps, never filters: everyone is still on the grid.
        expect(find.byKey(const Key('likelyHereChip_A0')), findsNothing);
        await tester.scrollUntilVisible(
          find.byKey(const Key('likelyHereChip_A0')),
          -200,
          scrollable: find.descendant(of: grid, matching: find.byType(Scrollable)),
        );
        expect(find.byKey(const Key('likelyHereChip_A0')), findsOneWidget);
      });

      testWidgets('dragging along the strip scrubs to the letter under it',
          (tester) async {
        await pumpPage(tester, families: crowd);
        final top = tester.getRect(grid).top;
        final from = tester.getCenter(find.byKey(letter('B')));
        final to = tester.getCenter(find.byKey(letter('F')));

        final gesture = await tester.startGesture(from);
        await tester.pump();
        await gesture.moveTo(to);
        await tester.pump();
        expect(
          find.descendant(
            of: find.byKey(const Key('likelyHereLetterBubble')),
            matching: find.text('F'),
          ),
          findsOneWidget,
        );
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.getRect(find.byKey(const Key('likelyHereChip_F0'))).top,
            closeTo(top, 0.5));
      });

      testWidgets('a vertical drag in the left gutter scrubs too',
          (tester) async {
        await pumpPage(tester, families: crowd);
        final gridRect = tester.getRect(grid);
        final firstTile =
            tester.getRect(find.byKey(const Key('likelyHereChip_A0')));
        // The gutter is the grid's side padding, clear of the tiles.
        final x = (gridRect.left + firstTile.left) / 2;
        expect(x, lessThan(firstTile.left));
        final from = Offset(x, tester.getCenter(find.byKey(letter('A'))).dy);
        final to = Offset(x, tester.getCenter(find.byKey(letter('H'))).dy);

        final gesture = await tester.startGesture(from);
        await gesture.moveTo(from + const Offset(0, 30));
        await tester.pump();
        await gesture.moveTo(to);
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(tester.getRect(find.byKey(const Key('likelyHereChip_H0'))).top,
            closeTo(gridRect.top, 0.5));
      });

      testWidgets('is one adjustable control for screen readers',
          (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpPage(tester, families: crowd);
        final top = tester.getRect(grid).top;
        final node = find.semantics.byLabel('Jump to letter');

        expect(
          tester.getSemantics(find.byKey(strip)),
          containsSemantics(
            label: 'Jump to letter',
            value: 'A',
            isSlider: true,
            hasIncreaseAction: true,
          ),
        );

        tester.semantics.performAction(node, SemanticsAction.increase);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.byKey(strip)),
          containsSemantics(
            value: 'B',
            hasIncreaseAction: true,
            hasDecreaseAction: true,
          ),
        );
        expect(tester.getRect(find.byKey(const Key('likelyHereChip_B0'))).top,
            closeTo(top, 0.5));

        tester.semantics.performAction(node, SemanticsAction.decrease);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.byKey(strip)),
          containsSemantics(value: 'A'),
        );
        semantics.dispose();
      });

      testWidgets('follows the letter at the top while the grid scrolls',
          (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpPage(tester, families: crowd);
        final tile = tester.getRect(find.byKey(const Key('likelyHereChip_A0')));
        // About three rows down: the top row now starts with E1 (tiles go
        // A0 A1 B0 / B1 C0 C1 / D0 D1 E0 / E1 F0 F1).
        await tester.drag(grid, Offset(0, -3.3 * (tile.height + 8)));
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(find.byKey(strip)),
          containsSemantics(value: 'E'),
        );
        semantics.dispose();
      });
    });

    testWidgets('the grid has no search', (tester) async {
      await pumpPage(tester);
      expect(find.byKey(const Key('likelyHereSearch')), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('marking a chip does not push it to the end or shift other chips',
        (tester) async {
      await pumpPage(tester, withHistory: true);

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
      await pumpPage(tester);
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
      await pumpPage(tester,
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
      await pumpPage(tester);
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
      await pumpPage(tester, disableAnimations: false);
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
      await pumpPage(tester);
      expect(
        find.descendant(
          of: find.byType(ConvPressable),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });
  });

  group('every surface reports into the same session', () {
    testWidgets('a mark made here is saved to the session', (tester) async {
      final h = await pumpPage(tester);
      await tester.tap(find.byKey(const Key('likelyHereChip_duc')));
      await tester.pumpAndSettle();
      expect(await savedStatus(h.sessions, 'duc'), AttendanceStatus.present);
    });

    testWidgets('a guest can be added without leaving', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.byKey(const Key('likelyHereAddGuest')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('addSheetNameField')), findsOneWidget);
    });

    testWidgets('newly added attendee shows up in the Likely Here grid immediately',
        (tester) async {
      await pumpPage(tester);
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
      expect(find.text('Newbie'), findsOneWidget);
      expect(find.text('GUEST'), findsOneWidget);
      expect(find.text('Newbie Guest added · Here'), findsOneWidget);
      expect(find.byKey(const Key('addSheetNameField')), findsNothing);
    });

    for (final textScale in [1.0, 2.0]) {
      testWidgets(
          'the "added" snackbar floats above the Add someone pill '
          '(text scale $textScale)', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpPage(tester);

        await tester.tap(find.byKey(const Key('likelyHereAddGuest')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('addSheetNameField')),
          'Newbie Guest',
        );
        await tester.tap(find.byKey(const Key('addSheetAddToRoster')));
        await tester.pumpAndSettle();

        final snackBar = tester.getRect(find
            .ancestor(
              of: find.text('Newbie Guest added · Here'),
              matching: find.byType(Material),
            )
            .first);
        final pill = tester.getRect(find.byKey(const Key('likelyHereAddGuest')));
        expect(snackBar.bottom, lessThanOrEqualTo(pill.top));

        // A second add needn't wait for the snackbar to time out.
        await tester.tap(find.byKey(const Key('likelyHereAddGuest')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('addSheetNameField')), findsOneWidget);
      });
    }

    testWidgets('two guests marked in one session get their own tiles',
        (tester) async {
      final h = await pumpPage(tester);

      for (final name in ['Guest One', 'Guest Two']) {
        await tester.tap(find.byKey(const Key('likelyHereAddGuest')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('addSheetNameField')),
          name,
        );
        await tester.tap(find.byKey(const Key('addSheetMarkGuest')));
        await tester.pumpAndSettle();
      }
      ScaffoldMessenger.of(tester.element(find.byType(AttendanceDeckPage)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();

      // Each guest has its own tile under a distinct key; none share the
      // empty member id.
      expect(find.byKey(const Key('likelyHereChip_')), findsNothing);
      expect(find.byKey(const Key('likelyHereChip_visitor_Guest One')),
          findsOneWidget);
      expect(find.byKey(const Key('likelyHereChip_visitor_Guest Two')),
          findsOneWidget);
      // Same given name, told apart by the surname line.
      expect(find.text('Guest'), findsNWidgets(2));
      expect(find.text('ONE'), findsOneWidget);
      expect(find.text('TWO'), findsOneWidget);

      // Header tally counts both guests present; the four roster members
      // are still left.
      expect(
        find.descendant(
          of: find.byKey(const Key('headerTallyTail')),
          matching: find.text('4 left'),
        ),
        findsOneWidget,
      );
      expect(find.text('2'), findsOneWidget);

      // Both are saved as Guest Marks: present, with no member ID.
      final saved = await h.sessions.findSessionById('current');
      final guests = saved!.records.where((r) => r.memberId == null).toList();
      expect(guests.map((r) => r.attendee),
          unorderedEquals(['Guest One', 'Guest Two']));
      expect(guests.every((r) => r.status == AttendanceStatus.present), isTrue);

    });
  });

  group('a pre-marked session opens on the grid with those people marked', () {
    testWidgets('everyone arrives marked, and the grid can flip somebody',
        (tester) async {
      final h = await pumpPage(tester,
        seed: AttendanceStatus.present,
      );
      expect(find.text('0 left'), findsOneWidget);

      await tester.tap(find.byKey(const Key('likelyHereChip_bao')));
      await tester.pumpAndSettle();
      expect(await savedStatus(h.sessions, 'bao'), AttendanceStatus.absent);
      expect(find.text('1 left'), findsOneWidget);
    });

  });

  group('the grid survives a real phone', () {
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

    testWidgets('long names do not overflow at phone width', (tester) async {
      tester.view.physicalSize = const Size(822, 1782); // 411x891 logical
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await pumpPage(tester, families: longRoster);
      expect(tester.takeException(), isNull, reason: 'on entry');
    });
  });

  group('the "Add someone" pill grows into the add sheet', () {
    final pill = find.byKey(const Key('likelyHereAddGuest'));
    final bounds = find.byKey(convMorphSheetBoundsKey);
    final nameField = find.byKey(const Key('addSheetNameField'));

    Future<void> pumpPhone(WidgetTester tester) async {
      tester.view.physicalSize = const Size(822, 1782); // 411x891 logical
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await pumpPage(tester, disableAnimations: false);
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
      expect(find.text('Newbie'), findsOneWidget);
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
      await pumpPage(tester);
      await tester.tap(pill);
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
      final h = await pumpPage(tester,
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

    testWidgets('the tally rolls to the new counts', (tester) async {
      await pumpPage(tester, disableAnimations: false);
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

    testWidgets("Done's progress fill eases instead of jumping",
        (tester) async {
      await pumpPage(tester, disableAnimations: false);
      final fill = find.descendant(
        of: find.byKey(const Key('doneProgressFill')),
        matching: find.byType(ColoredBox),
      );
      final track = tester.getSize(find.byKey(const Key('finishSessionButton')));
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

    testWidgets("with motion off the tally and Done's fill snap",
        (tester) async {
      await pumpPage(tester);
      final fill = find.descendant(
        of: find.byKey(const Key('doneProgressFill')),
        matching: find.byType(ColoredBox),
      );
      final track = tester.getSize(find.byKey(const Key('finishSessionButton')));

      await tester.tap(find.byKey(const Key('likelyHereChip_duc')));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const Key('headerTallyTail')),
          matching: find.text('3 left'),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(fill).width, closeTo(track.width / 4, 0.01));
    });
  });

  group('Done carries the progress (#222 M6)', () {
    final done = find.byKey(const Key('finishSessionButton'));
    final fill = find.descendant(
      of: find.byKey(const Key('doneProgressFill')),
      matching: find.byType(ColoredBox),
    );
    final glow = find.byKey(doneGlowKey);

    Future<void> mark(WidgetTester tester, List<String> ids) async {
      for (final id in ids) {
        await tester.tap(find.byKey(Key('likelyHereChip_$id')));
        await tester.pump();
      }
    }

    Color? labelColor(WidgetTester tester) => tester
        .widget<Text>(
          find.descendant(of: done, matching: find.text('Done')),
        )
        .style
        ?.color;

    testWidgets('marking replaces the thin bar with the Done pill',
        (tester) async {
      await pumpPage(tester);
      expect(find.byKey(const Key('headerProgressPresent')), findsNothing);
      expect(find.byKey(const Key('headerProgressAbsent')), findsNothing);
      expect(tester.getSize(fill).width, 0);
      expect(glow, findsNothing);
    });

    testWidgets("Done's fill grows with each decision", (tester) async {
      await pumpPage(tester);
      final w = tester.getSize(done).width;
      await mark(tester, ['duc']);
      expect(tester.getSize(fill).width, closeTo(w / 4, 0.01));
      await mark(tester, ['an', 'bao']);
      expect(tester.getSize(fill).width, closeTo(w * 3 / 4, 0.01));
      expect(glow, findsNothing);
    });

    testWidgets('nobody left: fully violet, on-primary label, one glow',
        (tester) async {
      await pumpPage(tester, disableAnimations: false);
      final c = tester.element(done).conv;
      final w = tester.getSize(done).width;
      await mark(tester, ['duc', 'an', 'bao']);
      await tester.pumpAndSettle();
      expect(glow, findsNothing, reason: 'one person is still left');
      expect(labelColor(tester), isNot(c.onPrimary));

      await tester.tap(find.byKey(const Key('likelyHereChip_sam')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(glow, findsOneWidget);
      expect(tester.getSize(fill).width, closeTo(w, 0.01));
      expect(labelColor(tester), c.onPrimary);

      // The glow fades out once and does not come back.
      await tester.pump(const Duration(milliseconds: 500));
      expect(glow, findsNothing);
      expect(labelColor(tester), c.onPrimary);
    });

    testWidgets('with motion off completion is the same state, no glow',
        (tester) async {
      await pumpPage(tester);
      final c = tester.element(done).conv;
      await mark(tester, ['duc', 'an', 'bao', 'sam']);
      expect(glow, findsNothing);
      expect(
        tester.getSize(fill).width,
        closeTo(tester.getSize(done).width, 0.01),
      );
      expect(labelColor(tester), c.onPrimary);
    });

    testWidgets('Done still finishes the session', (tester) async {
      final h = await pumpPage(tester);
      await mark(tester, ['duc']);
      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(await savedStatus(h.sessions, 'duc'), AttendanceStatus.present);
    });
  });

  group('the header fits a real phone', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('stays whole at ${scale}x text on a phone', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await pumpPage(tester);

        // The header (tally, Done pill) and the grid fit without overflow.
        expect(tester.takeException(), isNull);
        final done = tester.getRect(find.byKey(const Key('finishSessionButton')));
        expect(done.left, greaterThanOrEqualTo(0));
        expect(done.right, lessThanOrEqualTo(390));
      });
    }
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

    /// Forty people, all "Member …": a newcomer named Zed sorts last, far
    /// below the fold.
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
      await pumpPage(tester,
        families: families,
        disableAnimations: disableAnimations,
        // The app's floating snackbar, which the flight lands on.
        theme: AppTheme.lightTheme(),
      );
    }

    /// The tile for [name], found by its given-name headline. The test
    /// directory cannot create members, so a newcomer is added id-less and
    /// keyed `likelyHereChip_`.
    Finder tileOf(String name) => find.ancestor(
          of: find.text(name.split(' ').first),
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
  });
}
