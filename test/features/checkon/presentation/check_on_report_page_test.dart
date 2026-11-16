import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:attendance_tracker/core/design/app_colors.dart';
import 'package:attendance_tracker/features/checkon/domain/check_on.dart';
import 'package:attendance_tracker/features/checkon/presentation/check_on_report_page.dart';
import 'package:attendance_tracker/features/checkon/presentation/check_on_widgets.dart';

import 'check_on_test_support.dart';

final _ann = checkOnMember('m1', 'Ann');
final _bob = checkOnMember('m2', 'Bob');

Future<FakeCheckOnEventRepository> _pump(
  WidgetTester tester, {
  bool twoEvents = false,
  bool disableAnimations = true,
}) async {
  final events = [
    checkOnEvent(),
    if (twoEvents) checkOnEvent(id: 'e2', title: 'Prayer'),
  ];
  final sessions = [
    // Ann is flagged on Study (strong), Bob on Study too, later.
    ...checkOnSessions({_ann: 'xx.....', _bob: 'xxxx...'}),
    if (twoEvents)
      ...checkOnSessions({_ann: 'xx....'}, eventId: 'e2', title: 'Prayer'),
  ];
  final repo = FakeCheckOnEventRepository(events);
  await tester.pumpWidget(
    MaterialApp(
      home: CheckOnReportPage(
        eventRepository: repo,
        sessionRepository: FakeCheckOnSessionRepository(sessions),
        attendanceRepository: FakeCheckOnAttendanceRepository([_ann, _bob]),
        disableAnimations: disableAnimations,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

double _y(WidgetTester tester, String name) =>
    tester.getTopLeft(find.text(name)).dy;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows the skeleton for at least 800ms, then the cards',
      (tester) async {
    final repo = FakeCheckOnEventRepository([checkOnEvent()]);
    await tester.pumpWidget(
      MaterialApp(
        home: CheckOnReportPage(
          eventRepository: repo,
          sessionRepository: FakeCheckOnSessionRepository(
            checkOnSessions({_ann: 'xx.....'}),
          ),
          attendanceRepository: FakeCheckOnAttendanceRepository([_ann]),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
        find.byKey(const ValueKey('checkon_report_skeleton')), findsOneWidget);
    expect(find.text('Ann'), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    expect(
        find.byKey(const ValueKey('checkon_report_skeleton')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('checkon_report_skeleton')), findsNothing);
    expect(find.text('Ann'), findsOneWidget);
  });

  testWidgets('one card per person with flag, reason, dots and no filter',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);

    expect(find.text('Who to check on'), findsOneWidget);
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Not coming recently'), findsNWidgets(2));
    expect(find.text('Missed the last 5 · last here Jan 14'), findsOneWidget);
    expect(find.text('Missed the last 3 · last here Jan 28'), findsOneWidget);
    expect(find.text('Study'), findsNWidgets(2));
    // The dot history carries a screen-reader label.
    expect(find.bySemanticsLabel('Last 8 meetings: came to 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Last 8 meetings: came to 4'), findsOneWidget);
    // One event: no filter. No settings or schedule text.
    expect(find.text('All'), findsNothing);
    expect(find.textContaining('Runs every'), findsNothing);
    expect(find.text('Always current. The same rules apply to every event.'),
        findsOneWidget);
    semantics.dispose();
  });

  testWidgets('event filter appears with several events and narrows the list',
      (tester) async {
    await _pump(tester, twoEvents: true);

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Prayer'), findsWidgets);
    // Ann has a line on each event, Bob only on Study.
    expect(find.text('Bob'), findsOneWidget);

    await tester.tap(find.widgetWithText(InkWell, 'Prayer').first);
    await tester.pumpAndSettle();
    expect(find.text('Ann'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);

    await tester.tap(find.widgetWithText(InkWell, 'All'));
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('the filter falls back to All when its event goes away',
      (tester) async {
    final repo = await _pump(tester, twoEvents: true);
    await tester.tap(find.widgetWithText(InkWell, 'Prayer').first);
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsNothing);

    repo.emit([repo.events.first]);
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('All'), findsNothing);
  });

  testWidgets('ticking drops the person to the bottom, dimmed; un-tick undoes',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final repo = await _pump(tester);
    expect(_y(tester, 'Ann'), lessThan(_y(tester, 'Bob')));

    // Semantics of the unticked button.
    expect(find.bySemanticsLabel('Mark Ann followed up'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('checkon_tick_m1')));
    await tester.pumpAndSettle();

    expect(_y(tester, 'Bob'), lessThan(_y(tester, 'Ann')));
    expect(find.bySemanticsLabel('Followed up with Ann, tap to undo'),
        findsOneWidget);
    final ticked = repo.updated.last.checkOnFollowUps['m1']!;
    expect(ticked.flag, CheckOnFlag.notComingRecently.name);
    expect(ticked.lastPresent, DateTime(2026, 1, 14));
    final opacity = tester.widget<Opacity>(find
        .ancestor(
          of: find.text('Ann'),
          matching: find.byType(Opacity),
        )
        .first);
    expect(opacity.opacity, lessThan(1));

    await tester.tap(find.byKey(const ValueKey('checkon_tick_m1')));
    await tester.pumpAndSettle();

    expect(_y(tester, 'Ann'), lessThan(_y(tester, 'Bob')));
    expect(repo.updated.last.checkOnFollowUps, isEmpty);
    semantics.dispose();
  });

  testWidgets('ticking a person on two events ticks both lines',
      (tester) async {
    final repo = await _pump(tester, twoEvents: true);

    await tester.tap(find.byKey(const ValueKey('checkon_tick_m1')));
    await tester.pumpAndSettle();

    expect(repo.updated.map((e) => e.id).toSet(), {'e1', 'e2'});
    expect(
        repo.events.every((e) => e.checkOnFollowUps.containsKey('m1')), isTrue);

    await tester.tap(find.byKey(const ValueKey('checkon_tick_m1')));
    await tester.pumpAndSettle();
    expect(repo.events.every((e) => e.checkOnFollowUps.isEmpty), isTrue);
  });

  testWidgets('stop flagging removes the line and Undo brings it back',
      (tester) async {
    final repo = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('checkon_stop_e1_m1')));
    await tester.pumpAndSettle();

    expect(find.text('Ann'), findsNothing);
    expect(find.text('Stopped flagging Ann on Study'), findsOneWidget);
    expect(repo.events.single.checkOnStopFlagging, {'m1'});

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Ann'), findsOneWidget);
    expect(repo.events.single.checkOnStopFlagging, isEmpty);
  });

  testWidgets('shows a calm empty state when nobody needs checking on',
      (tester) async {
    final repo = FakeCheckOnEventRepository([checkOnEvent()]);
    await tester.pumpWidget(
      MaterialApp(
        home: CheckOnReportPage(
          eventRepository: repo,
          sessionRepository: FakeCheckOnSessionRepository(
            checkOnSessions({_ann: 'xxxxxxx'}),
          ),
          attendanceRepository: FakeCheckOnAttendanceRepository([_ann]),
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Everyone's accounted for"), findsOneWidget);
  });

  testWidgets('back button pops the page', (tester) async {
    final repo = FakeCheckOnEventRepository([checkOnEvent()]);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CheckOnReportPage(
                  eventRepository: repo,
                  sessionRepository: FakeCheckOnSessionRepository(
                    checkOnSessions({_ann: 'xx.....'}),
                  ),
                  attendanceRepository: FakeCheckOnAttendanceRepository([_ann]),
                  disableAnimations: true,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Who to check on'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a repository failure still leaves the page usable',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CheckOnReportPage(
          eventRepository: FakeCheckOnEventRepository([checkOnEvent()]),
          sessionRepository: _ThrowingSessions(),
          attendanceRepository: FakeCheckOnAttendanceRepository([_ann]),
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Everyone's accounted for"), findsOneWidget);
  });

  group('CheckOnDots', () {
    testWidgets('label counts the meetings came to', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CheckOnDots(
              history: [
                CheckOnSlot.noMeetingYet,
                CheckOnSlot.came,
                CheckOnSlot.came,
                CheckOnSlot.missedEarlier,
                CheckOnSlot.came,
                CheckOnSlot.missedLately,
                CheckOnSlot.missedLately,
                CheckOnSlot.missedLately,
              ],
            ),
          ),
        ),
      );
      expect(
          find.bySemanticsLabel('Last 8 meetings: came to 3'), findsOneWidget);
      expect(find.byType(CheckOnDot), findsNWidgets(8));
      semantics.dispose();
    });

    testWidgets('repaints when the slot changes', (tester) async {
      Widget dot(CheckOnSlot s) =>
          MaterialApp(home: Scaffold(body: CheckOnDot(slot: s)));
      for (final s in CheckOnSlot.values) {
        await tester.pumpWidget(dot(s));
      }
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('dark theme renders the cards', (tester) async {
    final repo = FakeCheckOnEventRepository([checkOnEvent()]);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          extensions: const [ConvocationColors.dark],
        ),
        home: CheckOnReportPage(
          eventRepository: repo,
          sessionRepository: FakeCheckOnSessionRepository(
            checkOnSessions({_ann: 'xx.....'}),
          ),
          attendanceRepository: FakeCheckOnAttendanceRepository([_ann]),
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ann'), findsOneWidget);
  });
}

class _ThrowingSessions extends FakeCheckOnSessionRepository {
  _ThrowingSessions() : super(const []);

  @override
  Future<List<Never>> loadSessions() => throw StateError('boom');
}
