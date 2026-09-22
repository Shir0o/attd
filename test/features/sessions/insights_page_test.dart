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
import 'package:attendance_tracker/features/sessions/presentation/insights_page.dart';

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
}
