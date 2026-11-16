import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:attendance_tracker/core/design/app_colors.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/checkon/domain/check_on_board.dart';
import 'package:attendance_tracker/features/checkon/presentation/check_on_hub_card.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';

import 'check_on_test_support.dart';

Future<void> _pump(
  WidgetTester tester, {
  required List<Event> events,
  required List<Member> members,
  required Map<Member, String> patterns,
  VoidCallback? onOpen,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: CheckOnHubCard(
            events: events,
            members: members,
            sessions: checkOnSessions(patterns),
            onOpenReport: onOpen ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final ann = checkOnMember('m1', 'Ann');
  final bob = checkOnMember('m2', 'Bob');
  final cat = checkOnMember('m3', 'Cat');

  testWidgets('lists name, event, flag and dots, most serious first',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      events: [checkOnEvent()],
      members: [ann, bob, cat],
      // Ann: Not coming recently. Bob: Newcomer follow-up. Cat: fine.
      patterns: {ann: 'xx.....', bob: '------x', cat: 'xxxxxxx'},
    );
    // Bob came once, 0 weeks ago: newcomer; Ann is strong so first.
    expect(find.text('Who to check on'.toUpperCase()), findsOneWidget);
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Cat'), findsNothing);
    expect(find.text('Study'), findsNWidgets(2));
    expect(find.text('Not coming recently'), findsOneWidget);
    expect(find.text('Newcomer follow-up'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Ann')).dy,
      lessThan(tester.getTopLeft(find.text('Bob')).dy),
    );
    expect(find.bySemanticsLabel('Last 8 meetings: came to 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Last 8 meetings: came to 1'), findsOneWidget);
    expect(find.text('See why, and mark who you reached'), findsOneWidget);
    expect(find.byKey(const ValueKey('checkon_more')), findsNothing);
    semantics.dispose();
  });

  testWidgets('caps the list at six with a +N more affordance', (tester) async {
    final people = [
      for (var i = 1; i <= 8; i++) checkOnMember('p$i', 'Person $i'),
    ];
    var opened = 0;
    await _pump(
      tester,
      events: [checkOnEvent()],
      members: people,
      patterns: {for (final p in people) p: 'xx.....'},
      onOpen: () => opened++,
    );

    for (var i = 1; i <= kCheckOnHubCardMax; i++) {
      expect(find.text('Person $i'), findsOneWidget);
    }
    expect(find.text('Person 7'), findsNothing);
    expect(find.text('Person 8'), findsNothing);
    expect(find.text('+2 more'), findsOneWidget);

    await tester.tap(find.text('+2 more'));
    expect(opened, 1);
  });

  testWidgets('shows exactly six with no +N more', (tester) async {
    final people = [
      for (var i = 1; i <= 6; i++) checkOnMember('p$i', 'Person $i'),
    ];
    await _pump(
      tester,
      events: [checkOnEvent()],
      members: people,
      patterns: {for (final p in people) p: 'xx.....'},
    );
    expect(find.textContaining('more'), findsNothing);
    expect(find.text('Person 6'), findsOneWidget);
  });

  testWidgets('shows a calm empty state, with the footer still there',
      (tester) async {
    await _pump(
      tester,
      events: [checkOnEvent()],
      members: [ann],
      patterns: {ann: 'xxxxxxx'},
    );
    expect(find.text("Everyone's accounted for"), findsOneWidget);
    expect(find.text('Ann'), findsNothing);
    expect(find.text('See why, and mark who you reached'), findsOneWidget);
  });

  testWidgets('followed-up and stop-flagging people are not listed',
      (tester) async {
    final sessions = checkOnSessions({ann: 'xx.....', bob: 'xx.....'});
    final base = CheckOnBoard.compute(
      events: [checkOnEvent()],
      members: [ann, bob, cat],
      sessions: sessions,
    );
    final annEntry = base.entries.firstWhere((e) => e.memberId == 'm1');
    final event =
        checkOnEvent().withFollowUps([annEntry]).withStopFlagging('m2');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckOnHubCard(
            events: [event],
            members: [ann, bob, cat],
            sessions: sessions,
            onOpenReport: () {},
          ),
        ),
      ),
    );
    expect(find.text('Ann'), findsNothing);
    expect(find.text('Bob'), findsNothing);
    expect(find.text("Everyone's accounted for"), findsOneWidget);
  });

  testWidgets('a person on two events shows once, on their most serious line',
      (tester) async {
    final events = [
      checkOnEvent(),
      checkOnEvent(id: 'e2', title: 'Prayer'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckOnHubCard(
            events: events,
            members: [ann],
            sessions: [
              ...checkOnSessions({ann: 'xx.....'}),
              ...checkOnSessions({ann: 'xx....'},
                  eventId: 'e2', title: 'Prayer'),
            ],
            onOpenReport: () {},
          ),
        ),
      ),
    );
    expect(find.text('Ann'), findsOneWidget);
  });

  testWidgets('tapping a row or the footer opens the report', (tester) async {
    var opened = 0;
    await _pump(
      tester,
      events: [checkOnEvent()],
      members: [ann],
      patterns: {ann: 'xx.....'},
      onOpen: () => opened++,
    );
    await tester.tap(find.byKey(const ValueKey('checkon_row_m1')));
    await tester.tap(find.byKey(const ValueKey('checkon_open_report')));
    expect(opened, 2);
  });

  testWidgets('tap targets are at least 48dp tall', (tester) async {
    await _pump(
      tester,
      events: [checkOnEvent()],
      members: [ann],
      patterns: {ann: 'xx.....'},
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('checkon_row_m1'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('checkon_open_report'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('renders in the dark theme', (tester) async {
    await _pump(
      tester,
      events: [checkOnEvent()],
      members: [ann],
      patterns: {ann: 'xx.....'},
      theme: ThemeData(
        brightness: Brightness.dark,
        extensions: const [ConvocationColors.dark],
      ),
    );
    expect(find.text('Ann'), findsOneWidget);
  });
}
