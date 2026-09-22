import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:attendance_tracker/core/design/app_theme.dart';
import 'package:attendance_tracker/core/design/widgets/conv_widgets.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/sessions/domain/event_insights.dart';
import 'package:attendance_tracker/features/reports/report_export_page.dart';
import 'package:attendance_tracker/features/sessions/presentation/insights_page.dart';

import '../../helpers/mocks.dart';

DateTime _week(int i) => DateTime(2026, 1, 7).add(Duration(days: 7 * i));

Event _event({InsightsConfig? config, bool isReadOnly = false}) => Event(
      id: 'e1',
      title: 'Wednesday Study',
      time: const TimeOfDay(hour: 19, minute: 0),
      frequency: 'Weekly',
      insightsConfig: config,
      isReadOnly: isReadOnly,
      createdAt: DateTime(2026, 1, 1),
    );

SessionRecord _mark(
  String id,
  String name, {
  AttendanceStatus status = AttendanceStatus.present,
  bool isLate = false,
}) =>
    SessionRecord(
      memberId: id,
      attendee: name,
      status: status,
      recordedAt: DateTime(2026, 1, 1),
      recordedBy: 'user',
      isLate: isLate,
    );

Session _session(int i, List<SessionRecord> records) => Session(
      id: 's$i',
      eventId: 'e1',
      title: 'Wednesday Study',
      sessionDate: _week(i),
      records: records,
      createdAt: _week(i),
      updatedAt: _week(i),
      createdBy: 'user',
    );

final _alice = Member(id: 'm1', displayName: 'Alice Okonkwo');
final _bob = Member(id: 'm2', displayName: 'Bob Castellanos');
final _roster = [_alice, _bob];

List<Session> _weeks(int n) => [
      for (var i = 0; i < n; i++)
        _session(i, [
          _mark('m1', 'Alice Okonkwo'),
          _mark('m2', 'Bob Castellanos',
              status: i.isEven
                  ? AttendanceStatus.present
                  : AttendanceStatus.absent),
        ]),
    ];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget wrap(Widget child) =>
      MaterialApp(theme: AppTheme.lightTheme(), home: child);

  Future<void> pumpPage(
    WidgetTester tester, {
    required List<Session> sessions,
    InsightsConfig? config,
    bool isReadOnly = false,
    MockEventRepository? eventRepository,
    MockSessionRepository? sessionRepository,
  }) async {
    // A tall surface so the whole page is built: a ListView only builds what
    // is near the viewport, and the lower sections would otherwise be absent
    // from the tree rather than genuinely missing.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrap(
        InsightsPage(
          event: _event(config: config, isReadOnly: isReadOnly),
          sessions: sessions,
          members: _roster,
          eventRepository: eventRepository,
          sessionRepository: sessionRepository,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the headline rate and the event name', (tester) async {
    await pumpPage(tester, sessions: _weeks(8));

    expect(find.text('Wednesday Study'), findsWidgets);
    expect(find.text('INSIGHTS'), findsOneWidget);
    expect(find.textContaining('%'), findsWidgets);
  });

  testWidgets('shows the default sections and hides the opt-in ones',
      (tester) async {
    await pumpPage(tester, sessions: _weeks(8));

    expect(find.textContaining('REGULARS'), findsOneWidget);
    expect(find.textContaining('LAPSED'), findsOneWidget);
    expect(find.textContaining('EVERY ATTENDEE'), findsOneWidget);
    // Opt-in sections stay off until switched on.
    expect(find.textContaining('PEOPLE SEEN'), findsNothing);
    expect(find.textContaining('LONGEST STREAK'), findsNothing);
  });

  testWidgets('hides guests and lateness when there are none', (tester) async {
    await pumpPage(tester, sessions: _weeks(8));

    expect(find.text('GUESTS'), findsNothing);
    expect(find.text('LATE'), findsNothing);
  });

  testWidgets('shows guests and lateness once they have something to say',
      (tester) async {
    final sessions = [
      ..._weeks(7),
      _session(7, [
        _mark('m1', 'Alice Okonkwo', isLate: true),
        SessionRecord(
          memberId: null,
          attendee: 'Walk-in Wendy',
          status: AttendanceStatus.present,
          recordedAt: DateTime(2026, 1, 1),
          recordedBy: 'user',
        ),
      ]),
    ];
    await pumpPage(tester, sessions: sessions);

    expect(find.text('GUESTS'), findsOneWidget);
    expect(find.text('LATE'), findsOneWidget);
  });

  testWidgets('tells you how many more sessions a section needs',
      (tester) async {
    await pumpPage(tester, sessions: _weeks(3));

    // Regulars needs a window of 8; three recorded means five to go.
    expect(find.text('Needs 5 more sessions.'), findsOneWidget);
  });

  testWidgets('offers an empty state before any session is recorded',
      (tester) async {
    await pumpPage(tester, sessions: const []);

    expect(find.text('No sessions recorded yet'), findsOneWidget);
  });

  testWidgets('offers the range control across every section', (tester) async {
    await pumpPage(tester, sessions: _weeks(8));

    // One control, governing every section.
    expect(find.byType(ConvSegmented), findsOneWidget);
    for (final r in InsightsRange.values) {
      expect(find.text(r.label), findsWidgets);
    }
  });

  testWidgets('renders only the sections configuration allows', (tester) async {
    await pumpPage(
      tester,
      sessions: _weeks(8),
      config: const InsightsConfig(
        visibleSections: {InsightsSection.streaks},
      ),
    );

    expect(find.textContaining('LONGEST STREAK'), findsOneWidget);
    expect(find.textContaining('REGULARS'), findsNothing);
    expect(find.textContaining('EVERY ATTENDEE'), findsNothing);
  });

  testWidgets('customize sheet is read-only on a shared event you do not own',
      (tester) async {
    await pumpPage(tester, sessions: _weeks(8), isReadOnly: true);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('Set by the event owner'), findsOneWidget);

    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('section_regulars')),
    );
    expect(toggle.onChanged, isNull);
  });

  testWidgets('customize sheet is editable on an event you own',
      (tester) async {
    await pumpPage(tester, sessions: _weeks(8));

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('What this event counts'), findsOneWidget);

    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('section_regulars')),
    );
    expect(toggle.onChanged, isNotNull);
  });

  testWidgets('turning a section off through the sheet removes it',
      (tester) async {
    await pumpPage(tester, sessions: _weeks(8));
    expect(find.textContaining('REGULARS'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('section_regulars')));
    await tester.pumpAndSettle();

    final save = find.byType(FilledButton);
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.textContaining('REGULARS'), findsNothing);
  });

  /// Eight sessions where Bob is a former regular who then stops, Alice keeps
  /// a full streak, a guest walks in and someone arrives late — enough to make
  /// every section say something.
  List<Session> richHistory() => [
        for (var i = 0; i < 5; i++)
          _session(i, [
            _mark('m1', 'Alice Okonkwo'),
            _mark('m2', 'Bob Castellanos'),
          ]),
        for (var i = 5; i < 8; i++)
          _session(i, [
            _mark('m1', 'Alice Okonkwo', isLate: i == 7),
            _mark('m2', 'Bob Castellanos', status: AttendanceStatus.absent),
            if (i == 7)
              SessionRecord(
                memberId: null,
                attendee: 'Walk-in Wendy',
                status: AttendanceStatus.present,
                recordedAt: DateTime(2026, 1, 1),
                recordedBy: 'user',
              ),
          ]),
      ];

  testWidgets('renders every opt-in section when they are switched on',
      (tester) async {
    await pumpPage(
      tester,
      sessions: richHistory(),
      config: InsightsConfig(visibleSections: InsightsSection.values.toSet()),
    );

    expect(find.textContaining('PEOPLE SEEN'), findsOneWidget);
    expect(find.textContaining('FIRST-TIMERS'), findsOneWidget);
    expect(find.text('LONGEST STREAK'), findsOneWidget);
    expect(find.text('MEDIAN'), findsOneWidget);
    expect(find.text('GUESTS'), findsOneWidget);
    expect(find.text('LATE'), findsOneWidget);
  });

  testWidgets('names a lapsed attendee with what they used to attend',
      (tester) async {
    await pumpPage(tester, sessions: richHistory());

    expect(find.textContaining('LAPSED · 1'), findsOneWidget);
    expect(find.text('Bob Castellanos'), findsWidgets);
    expect(find.textContaining('missed last 3'), findsOneWidget);
  });

  testWidgets('says so when nobody has lapsed', (tester) async {
    await pumpPage(tester, sessions: _weeks(8));

    expect(
      find.text('Nobody who was a regular has stopped coming.'),
      findsOneWidget,
    );
  });

  testWidgets('sorts the member table by rate or by name', (tester) async {
    await pumpPage(tester, sessions: richHistory());

    expect(find.text('Rate'), findsOneWidget);
    await tester.tap(find.text('Rate'));
    await tester.pumpAndSettle();
    expect(find.text('Name'), findsOneWidget);
  });

  testWidgets('expands and collapses the member table', (tester) async {
    await pumpPage(tester, sessions: richHistory());

    // Two on the roster, so the collapsed cap is never reached and the
    // control stays out of the way.
    expect(find.textContaining('Show all'), findsNothing);
  });

  testWidgets('changing the range saves it on the event', (tester) async {
    final repo = MockEventRepository()..emit([_event()]);
    await pumpPage(
      tester,
      sessions: _weeks(8),
      eventRepository: repo,
    );

    await tester.tap(find.text(InsightsRange.sixMonths.label));
    await tester.pumpAndSettle();

    final saved = await repo.findEventById('e1');
    expect(saved?.insightsConfig?.range, InsightsRange.sixMonths);
  });

  testWidgets('does not write configuration back to a read-only event',
      (tester) async {
    final repo = MockEventRepository()..emit([_event()]);
    await pumpPage(
      tester,
      sessions: _weeks(8),
      eventRepository: repo,
      isReadOnly: true,
    );

    await tester.tap(find.text(InsightsRange.year.label));
    await tester.pumpAndSettle();

    // The view follows along, but nothing is written back to an event the
    // user cannot save.
    final stored = await repo.findEventById('e1');
    expect(stored?.insightsConfig, isNull);
  });

  testWidgets('export opens the existing report flow', (tester) async {
    final sessions = _weeks(8);
    final sessionRepo = MockSessionRepository()..setSessions(sessions);
    await pumpPage(
      tester,
      sessions: sessions,
      sessionRepository: sessionRepo,
    );

    await tester.tap(find.byIcon(Icons.ios_share_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(ReportExportPage), findsOneWidget);
  });

  testWidgets('offers no export when there is no repository to export from',
      (tester) async {
    await pumpPage(tester, sessions: _weeks(8));

    expect(find.byIcon(Icons.ios_share_outlined), findsNothing);
  });

  testWidgets('the customize steppers move the thresholds', (tester) async {
    await pumpPage(tester, sessions: _weeks(8));

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('80% of the last 8 sessions'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove).first);
    await tester.pumpAndSettle();
    expect(find.text('70% of the last 8 sessions'), findsOneWidget);

    expect(find.text('3 missed sessions in a row'), findsOneWidget);
    expect(find.text('Judged on 4 prior sessions'), findsOneWidget);
  });

  testWidgets('every section can say how much more history it needs',
      (tester) async {
    await pumpPage(
      tester,
      sessions: _weeks(1),
      config: InsightsConfig(visibleSections: InsightsSection.values.toSet()),
    );

    // One session: the windowed sections cannot speak yet, and each says so
    // under its own name rather than vanishing.
    expect(find.textContaining('Needs '), findsWidgets);
    expect(find.text('REGULARS'), findsOneWidget);
    expect(find.text('LAPSED'), findsOneWidget);
    expect(find.text('ATTENDANCE RATE'), findsOneWidget);
    expect(find.text('PEOPLE SEEN'), findsOneWidget);
  });

  testWidgets('says plainly when nobody clears the regulars bar',
      (tester) async {
    final sessions = [
      for (var i = 0; i < 8; i++)
        _session(i, [
          _mark('m1', 'Alice Okonkwo', status: AttendanceStatus.absent),
          _mark('m2', 'Bob Castellanos', status: AttendanceStatus.absent),
        ]),
    ];
    await pumpPage(tester, sessions: sessions);

    expect(
      find.text('Nobody clears 80% of the last 8 sessions yet.'),
      findsOneWidget,
    );
  });

  testWidgets('says plainly when nobody is new in the range', (tester) async {
    final sessions = [
      for (var i = 0; i < 20; i++) _session(i, [_mark('m1', 'Alice Okonkwo')]),
    ];
    await pumpPage(
      tester,
      sessions: sessions,
      config: const InsightsConfig(
        visibleSections: {InsightsSection.firstTimers},
      ),
    );

    expect(find.text('Nobody new in this range.'), findsOneWidget);
  });

  testWidgets('expands a long roster and collapses it again', (tester) async {
    final many = [
      for (var i = 0; i < 16; i++)
        Member(id: 'x$i', displayName: 'Person ${i.toString().padLeft(2, '0')}'),
    ];
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        InsightsPage(
          event: _event(
            config: const InsightsConfig(
              visibleSections: {InsightsSection.memberTable},
            ),
          ),
          sessions: [
            for (var i = 0; i < 4; i++)
              _session(i, [for (final m in many) _mark(m.id, m.displayName)]),
          ],
          members: many,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Show all 16'), findsOneWidget);
    expect(find.text('Person 15'), findsNothing);

    await tester.tap(find.text('Show all 16'));
    await tester.pumpAndSettle();
    expect(find.text('Person 15'), findsOneWidget);
    expect(find.text('Show fewer'), findsOneWidget);

    await tester.tap(find.text('Show fewer'));
    await tester.pumpAndSettle();
    expect(find.text('Show all 16'), findsOneWidget);
  });

  testWidgets('every customize stepper moves in both directions',
      (tester) async {
    await pumpPage(tester, sessions: _weeks(8));
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    final plus = find.byIcon(Icons.add);
    final minus = find.byIcon(Icons.remove);

    // Regular threshold, then its window.
    await tester.tap(plus.at(0));
    await tester.pumpAndSettle();
    expect(find.text('90% of the last 8 sessions'), findsOneWidget);
    await tester.tap(plus.at(1));
    await tester.pumpAndSettle();
    expect(find.text('Window of 10 sessions'), findsOneWidget);
    await tester.tap(minus.at(1));
    await tester.pumpAndSettle();
    expect(find.text('Window of 8 sessions'), findsOneWidget);

    // Lapsed run, then the minimum history behind a verdict.
    await tester.tap(plus.at(2));
    await tester.pumpAndSettle();
    expect(find.text('4 missed sessions in a row'), findsOneWidget);
    await tester.tap(minus.at(2));
    await tester.pumpAndSettle();
    expect(find.text('3 missed sessions in a row'), findsOneWidget);
    await tester.tap(plus.at(3));
    await tester.pumpAndSettle();
    expect(find.text('Judged on 5 prior sessions'), findsOneWidget);
    await tester.tap(minus.at(3));
    await tester.pumpAndSettle();
    expect(find.text('Judged on 4 prior sessions'), findsOneWidget);
  });

  testWidgets('switching a section back on restores it', (tester) async {
    await pumpPage(tester, sessions: _weeks(8));

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('section_streaks')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('LONGEST STREAK'), findsOneWidget);
  });
}
