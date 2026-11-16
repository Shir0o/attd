import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/presentation/session_summary_page.dart';
import 'package:attendance_tracker/features/checkon/presentation/check_on_report_page.dart';
import 'package:attendance_tracker/features/checkon/presentation/check_on_summary_line.dart';

import 'check_on_test_support.dart';

final _ann = checkOnMember('m1', 'Ann');
final _bob = checkOnMember('m2', 'Bob');
final _cat = checkOnMember('m3', 'Cat');

const _lineKey = ValueKey('checkon_summary_line');

Future<void> _pumpSummary(
  WidgetTester tester, {
  required Map<Member, String> patterns,
  bool withRepos = true,
}) async {
  final members = [_ann, _bob, _cat];
  final sessions = checkOnSessions(patterns);
  final event = checkOnEvent().copyWith(memberIds: ['m1', 'm2', 'm3']);
  await tester.pumpWidget(
    MaterialApp(
      home: SessionSummaryPage(
        session: sessions.last,
        members: members,
        sessionRepository: FakeCheckOnSessionRepository(sessions),
        attendanceRepository:
            withRepos ? FakeCheckOnAttendanceRepository(members) : null,
        eventRepository: withRepos ? FakeCheckOnEventRepository([event]) : null,
        event: event,
        disableAnimations: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows how many people to check on and opens the report',
      (tester) async {
    await _pumpSummary(
      tester,
      patterns: {_ann: 'xx.....', _bob: 'xxxx...', _cat: 'xxxxxxx'},
    );

    expect(find.byKey(_lineKey), findsOneWidget);
    expect(find.text('2 people to check on'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(_lineKey)).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.byKey(_lineKey));
    await tester.pumpAndSettle();
    expect(find.byType(CheckOnReportPage), findsOneWidget);
  });

  testWidgets('says "1 person" for one', (tester) async {
    await _pumpSummary(
      tester,
      patterns: {_ann: 'xx.....', _bob: 'xxxxxxx', _cat: 'xxxxxxx'},
    );
    expect(find.text('1 person to check on'), findsOneWidget);
  });

  testWidgets('is absent when nobody needs checking on', (tester) async {
    await _pumpSummary(
      tester,
      patterns: {_ann: 'xxxxxxx', _bob: 'xxxxxxx', _cat: 'xxxxxxx'},
    );
    expect(find.byKey(_lineKey), findsNothing);
    expect(find.textContaining('to check on'), findsNothing);
  });

  testWidgets('is absent when the page has no repositories to open from',
      (tester) async {
    await _pumpSummary(
      tester,
      patterns: {_ann: 'xx.....', _bob: 'xxxx...', _cat: 'xxxxxxx'},
      withRepos: false,
    );
    expect(find.byKey(_lineKey), findsNothing);
  });

  testWidgets('counts the session as the page holds it, before it is saved',
      (tester) async {
    // The repository still has Ann present at the latest session; the page
    // holds the session where she was marked absent.
    final members = [_ann];
    final saved = checkOnSessions({_ann: 'xx...x'});
    final held = checkOnSessions({_ann: 'xx....'}).last;
    final event = checkOnEvent().copyWith(memberIds: ['m1']);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckOnSummaryLine(
            event: event,
            session: held,
            members: members,
            sessionRepository: FakeCheckOnSessionRepository(saved),
            eventRepository: FakeCheckOnEventRepository([event]),
            attendanceRepository: FakeCheckOnAttendanceRepository(members),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 person to check on'), findsOneWidget);
  });

  testWidgets('a failing session load leaves the line hidden', (tester) async {
    final event = checkOnEvent().copyWith(memberIds: ['m1']);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckOnSummaryLine(
            event: event,
            session: checkOnSessions({_ann: 'xxxx'}).last,
            members: [_ann],
            sessionRepository: _Throwing(),
            eventRepository: FakeCheckOnEventRepository([event]),
            attendanceRepository: FakeCheckOnAttendanceRepository([_ann]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_lineKey), findsNothing);
  });
}

class _Throwing extends FakeCheckOnSessionRepository {
  _Throwing() : super(const []);

  @override
  Future<List<Never>> loadSessions() => throw StateError('boom');
}
