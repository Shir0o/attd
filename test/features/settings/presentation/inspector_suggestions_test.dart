import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/settings/presentation/manage_backup_data_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'inspector_test_fakes.dart';

final _t = DateTime(2025, 4, 5, 10);
final _day = DateTime(2025, 4, 5);

SessionRecord _mark(String? memberId, String attendee, int minute,
        {AttendanceStatus status = AttendanceStatus.present}) =>
    SessionRecord(
      memberId: memberId,
      attendee: attendee,
      status: status,
      recordedAt: _t.add(Duration(minutes: minute)),
      recordedBy: 'tester',
    );

Session _session(String id, List<SessionRecord> records,
        {String title = 'Weekly', String? eventId = 'e-1', DateTime? deletedAt, String createdBy = 'tester'}) =>
    Session(
      id: id,
      title: title,
      eventId: eventId,
      sessionDate: _day,
      records: records,
      createdAt: _t,
      updatedAt: _t,
      createdBy: createdBy,
      deletedAt: deletedAt,
    );

String _markId(String sessionId, String who, int minute) =>
    '${sessionId}_${who}_${_t.add(Duration(minutes: minute)).millisecondsSinceEpoch}';

class _Harness {
  _Harness({List<Family>? families, List<Event>? events, required List<Session> sessions})
      : families = InspectorFamilies(families ??
            [
              Family(id: 'f-1', displayName: 'Alpha', updatedAt: _t, members: [
                Member(id: 'm-ann', displayName: 'Ann Alpha', updatedAt: _t),
                Member(id: 'm-zoe', displayName: 'Zoe Alvarez', updatedAt: _t),
                Member(id: 'm-zoe-old', displayName: 'Zoe Alvarez', updatedAt: _t, deletedAt: _t),
              ]),
            ]),
        events = InspectorEvents(events ??
            [Event(id: 'e-1', title: 'Weekly', time: const TimeOfDay(hour: 10, minute: 0), frequency: 'Weekly', createdAt: _t)]),
        sessions = InspectorSessions(sessions);

  final InspectorFamilies families;
  final InspectorEvents events;
  final InspectorSessions sessions;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(
      home: ManageBackupDataPage(
        attendanceRepository: families,
        eventRepository: events,
        sessionRepository: sessions,
        disableAnimations: true,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Session session(String id) => sessions.sessions.firstWhere((s) => s.id == id);
}

Future<void> _open(WidgetTester tester, String text) async {
  await tester.tap(find.textContaining(text).first);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('flags are suggestions: no bulk clean-up, count shows what to review', (tester) async {
    final h = _Harness(sessions: [
      _session('s-1', [_mark('m-ann', 'Ann Alpha', 0)]),
      _session('s-2', [_mark('m-ann', 'Ann Alpha', 1)]),
    ]);
    await h.pump(tester);

    expect(find.byKey(const ValueKey('cleanup_flagged_records_button')), findsNothing);
    expect(find.textContaining('1 to review'), findsOneWidget);
  });

  testWidgets('duplicate mark shows the session it sits in and where else it was recorded', (tester) async {
    final h = _Harness(sessions: [
      _session('s-1', [_mark('m-ann', 'Ann Alpha', 0), _mark('m-zoe', 'Zoe Alvarez', 2)], createdBy: 'Tony'),
      _session('s-2', [_mark('m-ann', 'Ann Alpha', 1)], createdBy: 'Kevin'),
    ]);
    await h.pump(tester);

    await tester.tap(find.text('DUPLICATE'));
    await tester.pumpAndSettle();

    final panel = find.byKey(ValueKey('context_${_markId('s-2', 'm-ann', 1)}'));
    expect(panel, findsOneWidget);
    // This session's own marks, with the creator
    expect(find.descendant(of: panel, matching: find.textContaining('In this session')), findsOneWidget);
    expect(find.descendant(of: panel, matching: find.textContaining('Kevin')), findsWidgets);
    // The other session holding the same person on the same date
    expect(find.descendant(of: panel, matching: find.textContaining('Also recorded in')), findsOneWidget);
    expect(find.descendant(of: panel, matching: find.textContaining('Tony')), findsWidgets);
    expect(find.descendant(of: panel, matching: find.textContaining('Zoe Alvarez')), findsWidgets);
  });

  testWidgets('deleting a mark can be undone', (tester) async {
    final h = _Harness(sessions: [
      _session('s-1', [_mark('m-ann', 'Ann Alpha', 0), _mark('m-zoe', 'Zoe Alvarez', 2)]),
    ]);
    await h.pump(tester);

    await _open(tester, 'Weekly · Zoe Alvarez');
    await _tapKey(tester, 'delete_btn_${_markId('s-1', 'm-zoe', 2)}');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(h.session('s-1').records, hasLength(1));

    await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
    await tester.pumpAndSettle();
    expect(h.session('s-1').records.map((r) => r.attendee), containsAll(['Ann Alpha', 'Zoe Alvarez']));
    expect(h.session('s-1').updatedAt.isAfter(_t), isTrue, reason: 'undo must win the next sync merge');
  });

  testWidgets('orphaned mark can be linked to a live member with the same name', (tester) async {
    final h = _Harness(sessions: [
      _session('s-1', [_mark('m-zoe-old', 'Zoe Alvarez', 0)]),
    ]);
    await h.pump(tester);

    await tester.tap(find.text('ORPHANED'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'link_btn_${_markId('s-1', 'm-zoe-old', 0)}_m-zoe');

    final rec = h.session('s-1').records.single;
    expect(rec.memberId, 'm-zoe');
    expect(h.session('s-1').updatedAt.isAfter(_t), isTrue);
    expect(find.text('ORPHANED'), findsNothing);
  });

  testWidgets('orphaned mark can be kept as a guest mark', (tester) async {
    final h = _Harness(sessions: [
      _session('s-1', [_mark('m-gone', 'Merry Tang', 0)]),
    ]);
    await h.pump(tester);

    await tester.tap(find.text('ORPHANED'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'guest_btn_${_markId('s-1', 'm-gone', 0)}');

    final rec = h.session('s-1').records.single;
    expect(rec.memberId, isNull);
    expect(rec.attendee, 'Merry Tang');
    expect(find.text('ORPHANED'), findsNothing);
  });

  testWidgets('mark status can be changed', (tester) async {
    final h = _Harness(sessions: [
      _session('s-1', [_mark('m-ann', 'Ann Alpha', 0)]),
    ]);
    await h.pump(tester);

    await _open(tester, 'Weekly · Ann Alpha');
    await _tapKey(tester, 'status_btn_${_markId('s-1', 'm-ann', 0)}_absent');

    expect(h.session('s-1').records.single.status, AttendanceStatus.absent);
  });

  testWidgets('deleting a session leaves a tombstone and can be restored', (tester) async {
    final h = _Harness(sessions: [
      _session('s-empty', const []),
    ]);
    await h.pump(tester);

    await tester.tap(find.text('ORPHANED'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'delete_btn_s-empty');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(h.session('s-empty').deletedAt, isNotNull);

    // The row stays open, now offering Restore
    await _tapKey(tester, 'restore_btn_s-empty');
    expect(h.session('s-empty').deletedAt, isNull);
    expect(h.session('s-empty').updatedAt.isAfter(_t), isTrue);
  });

  testWidgets('dismissing a suggestion removes it from review and survives reload', (tester) async {
    final h = _Harness(sessions: [
      _session('s-1', [_mark('m-ann', 'Ann Alpha', 0)]),
      _session('s-2', [_mark('m-ann', 'Ann Alpha', 1)]),
    ]);
    await h.pump(tester);

    await tester.tap(find.text('DUPLICATE'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'dismiss_btn_${_markId('s-2', 'm-ann', 1)}');
    expect(find.textContaining('to review'), findsNothing);

    await h.pump(tester);
    expect(find.textContaining('to review'), findsNothing);
    expect(h.session('s-2').records, hasLength(1), reason: 'dismissing never changes data');
  });

  testWidgets('soft-deleted events, families and members can be restored', (tester) async {
    final h = _Harness(
      families: [
        Family(id: 'f-gone', displayName: 'Gone Family', updatedAt: _t, deletedAt: _t, members: const []),
        Family(id: 'f-1', displayName: 'Alpha', updatedAt: _t, members: [
          Member(id: 'm-old', displayName: 'Old Olga', updatedAt: _t, deletedAt: _t),
        ]),
      ],
      events: [
        Event(id: 'e-gone', title: 'Gone Event', time: const TimeOfDay(hour: 9, minute: 0), frequency: 'Weekly', createdAt: _t, deletedAt: _t),
      ],
      sessions: const [],
    );
    await h.pump(tester);

    for (final (title, id) in [('Gone Event', 'e-gone'), ('Gone Family', 'f-gone'), ('Old Olga', 'm-old')]) {
      await _open(tester, title);
      await _tapKey(tester, 'restore_btn_$id');
    }

    expect(h.events.events.single.deletedAt, isNull);
    expect(h.families.families.firstWhere((f) => f.id == 'f-gone').deletedAt, isNull);
    final olga = h.families.families.firstWhere((f) => f.id == 'f-1').members.single;
    expect(olga.deletedAt, isNull);
    expect(olga.updatedAt.isAfter(_t), isTrue);
  });

  testWidgets('deleting an event and a family can be undone', (tester) async {
    final h = _Harness(sessions: const []);
    await h.pump(tester);

    await _open(tester, 'Weekly');
    await _tapKey(tester, 'delete_btn_e-1');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(h.events.events.single.deletedAt, isNotNull);
    await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
    await tester.pumpAndSettle();
    expect(h.events.events.single.deletedAt, isNull);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'delete_btn_f-1');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(h.families.families.single.deletedAt, isNotNull);
    await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
    await tester.pumpAndSettle();
    expect(h.families.families.single.deletedAt, isNull);
    expect(h.families.families.single.updatedAt.isAfter(_t), isTrue);
  });

  testWidgets('a dismissed suggestion can be put back up for review', (tester) async {
    final h = _Harness(sessions: [_session('s-empty', const [])]);
    await h.pump(tester);

    await tester.tap(find.text('ORPHANED'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'dismiss_btn_s-empty');
    expect(find.textContaining('to review'), findsNothing);

    await _tapKey(tester, 'undismiss_btn_s-empty');
    expect(find.textContaining('1 to review'), findsOneWidget);
  });

  testWidgets('session context names a deleted event and lists sibling sessions', (tester) async {
    final h = _Harness(
      events: [
        Event(id: 'e-1', title: 'Weekly', time: const TimeOfDay(hour: 10, minute: 0), frequency: 'Weekly', createdAt: _t, deletedAt: _t),
      ],
      sessions: [
        _session('s-1', [_mark('m-ann', 'Ann Alpha', 0)]),
        _session('s-2', [_mark('m-zoe', 'Zoe Alvarez', 1)]),
      ],
    );
    await h.pump(tester);

    await tester.tap(find.text('ORPHANED').first);
    await tester.pumpAndSettle();
    expect(find.text('Event deleted: Weekly'), findsOneWidget);
    expect(find.text('1 other session on this date'), findsOneWidget);
  });
}
