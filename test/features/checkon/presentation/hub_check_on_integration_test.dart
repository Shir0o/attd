import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_tracker/features/checkon/presentation/check_on_hub_card.dart';
import 'package:attendance_tracker/features/checkon/presentation/check_on_report_page.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/hub/presentation/hub_attendance_view.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';

import 'check_on_test_support.dart';

final _ann = checkOnMember('m1', 'Ann');

Event _event() {
  final day = DateFormat('EEEE').format(DateTime.now());
  return checkOnEvent().copyWith(repeatingDays: [day], memberIds: ['m1']);
}

Future<void> _pumpHub(
  WidgetTester tester, {
  required FakeCheckOnEventRepository events,
  required FakeCheckOnSessionRepository sessions,
  required FakeCheckOnAttendanceRepository families,
  bool disableAnimations = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    MaterialApp(
      home: HubAttendanceView(
        themeController: ThemeController(prefs),
        sessionRepository: sessions,
        eventRepository: events,
        attendanceRepository: families,
        disableAnimations: disableAnimations,
      ),
    ),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('the card sits above the event list and opens the report',
      (tester) async {
    final events = FakeCheckOnEventRepository([_event()]);
    await _pumpHub(
      tester,
      events: events,
      sessions: FakeCheckOnSessionRepository(
        checkOnSessions({_ann: 'xx.....'}),
      ),
      families: FakeCheckOnAttendanceRepository([_ann]),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('checkon_hub_card'));
    expect(card, findsOneWidget);
    expect(find.text('Ann'), findsOneWidget);
    expect(
      tester.getTopLeft(card).dy,
      lessThan(tester.getTopLeft(find.text('Study').last).dy),
    );

    await tester.tap(find.byKey(const ValueKey('checkon_open_report')));
    await tester.pumpAndSettle();
    expect(find.byType(CheckOnReportPage), findsOneWidget);

    // Ticking on the report removes Ann from the hub card behind it.
    await tester.tap(find.byKey(const ValueKey('checkon_tick_m1')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(CheckOnReportPage), findsNothing);
    expect(find.text("Everyone's accounted for"), findsOneWidget);
  });

  testWidgets('the skeleton shows first and the card waits for the data',
      (tester) async {
    final events = FakeCheckOnEventRepository([_event()]);
    await _pumpHub(
      tester,
      events: events,
      sessions: FakeCheckOnSessionRepository(
        checkOnSessions({_ann: 'xx.....'}),
      ),
      families: FakeCheckOnAttendanceRepository([_ann]),
      disableAnimations: false,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('hub_skeleton')), findsOneWidget);
    expect(find.byType(CheckOnHubCard), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('hub_skeleton')), findsNothing);
    expect(find.byType(CheckOnHubCard), findsOneWidget);
  });

  testWidgets('no card without events', (tester) async {
    await _pumpHub(
      tester,
      events: FakeCheckOnEventRepository([]),
      sessions: FakeCheckOnSessionRepository(const []),
      families: FakeCheckOnAttendanceRepository([_ann]),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CheckOnHubCard), findsNothing);
  });
}
