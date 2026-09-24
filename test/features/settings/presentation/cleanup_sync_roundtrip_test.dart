import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/settings/data/drive_service.dart';
import 'package:attendance_tracker/features/settings/presentation/manage_backup_data_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'inspector_test_fakes.dart';

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

final _t = DateTime(2025, 4, 5, 10);
final _day = DateTime(2025, 4, 5);

SessionRecord _mark(String? memberId, String attendee, int minute) => SessionRecord(
      memberId: memberId,
      attendee: attendee,
      status: AttendanceStatus.present,
      recordedAt: _t.add(Duration(minutes: minute)),
      recordedBy: 'tester',
    );

Session _session(String id, String title, String? eventId, List<SessionRecord> records,
        {DateTime? deletedAt}) =>
    Session(
      id: id,
      title: title,
      eventId: eventId,
      sessionDate: _day,
      records: records,
      createdAt: _t,
      updatedAt: _t,
      createdBy: 'tester',
      deletedAt: deletedAt,
    );

String _issueLabel(WidgetTester tester) {
  for (var n = 1; n <= 20; n++) {
    if (find.textContaining('$n to review').evaluate().isNotEmpty) return '$n to review';
  }
  return 'nothing to review';
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('deletions in the inspector survive a Drive sync round-trip', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final families = InspectorFamilies([
      Family(id: 'f-1', displayName: 'Alpha', updatedAt: _t, members: [
        Member(id: 'm-1', displayName: 'Ann Alpha', updatedAt: _t),
        Member(id: 'm-hidden', displayName: 'Hid Den', updatedAt: _t, deletedAt: _t),
      ]),
      Family(id: 'f-empty', displayName: 'Empty', updatedAt: _t, members: const []),
      Family(id: 'f-deleted', displayName: 'Gone', updatedAt: _t, deletedAt: _t, members: const []),
    ]);
    final events = InspectorEvents([
      Event(id: 'e-1', title: 'Weekly', time: const TimeOfDay(hour: 10, minute: 0), frequency: 'Weekly', createdAt: _t),
      Event(id: 'e-hidden', title: 'Old', time: const TimeOfDay(hour: 9, minute: 0), frequency: 'Weekly', createdAt: _t, deletedAt: _t),
    ]);
    final sessions = InspectorSessions([
      _session('s-1', 'Weekly', 'e-1', [
        _mark('m-1', 'Ann Alpha', 0),
        _mark(null, 'Nobody Known', 1), // unlinked
        _mark('m-gone', 'Gone Person', 2), // orphan mark
      ]),
      _session('s-2', 'Weekly', 'e-1', [_mark('m-1', 'Ann Alpha', 3)]), // duplicate
      _session('s-orphan', 'Lost', 'e-missing', [_mark('m-1', 'Ann Alpha', 4)]), // orphan session
      _session('s-empty', 'Weekly', 'e-1', const []), // empty session
      _session('s-hidden', 'Weekly', 'e-1', [_mark('m-1', 'Ann Alpha', 5)], deletedAt: _t),
    ]);

    // What Drive holds: the state from the last sync, before cleanup.
    final remote = {
      'families.json': families.families.map((f) => f.toJson()).toList(),
      'events.json': events.events.map((e) => e.toJson()).toList(),
      'sessions.json': sessions.sessions.map((s) => s.toJson()).toList(),
    };

    Future<void> pumpPage() async {
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

    await pumpPage();
    // Guest marks and soft-deleted records are not issues.
    expect(_issueLabel(tester), '5 to review');

    Future<void> deleteRow(String title, String id) async {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('delete_btn_$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
    }

    await deleteRow('Empty', 'f-empty');
    await deleteRow('Lost', 's-orphan');
    final afterCleanup = _issueLabel(tester);
    expect(afterCleanup, '3 to review');
    expect(sessions.sessions.firstWhere((s) => s.id == 's-orphan').deletedAt, isNotNull);
    expect(families.families.firstWhere((f) => f.id == 'f-empty').deletedAt, isNotNull);

    // Simulate the sync: merge local with the Drive copy using the real engine.
    final signIn = _MockGoogleSignIn();
    when(() => signIn.authenticationEvents)
        .thenAnswer((_) => const Stream<GoogleSignInAuthenticationEvent>.empty());
    final drive = DriveService(googleSignIn: signIn);
    List<dynamic> merge(String file, List<dynamic> local) =>
        drive.testMergeJsonLists(local, remote[file]!, file);

    families.families = merge('families.json', families.families.map((f) => f.toJson()).toList())
        .map((j) => Family.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
    events.events = merge('events.json', events.events.map((e) => e.toJson()).toList())
        .map((j) => Event.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
    sessions.sessions = merge('sessions.json', sessions.sessions.map((s) => s.toJson()).toList())
        .map((j) => Session.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();

    await pumpPage();
    expect(_issueLabel(tester), afterCleanup, reason: 'sync must not bring cleaned records back');
    expect(sessions.sessions.firstWhere((s) => s.id == 's-orphan').deletedAt, isNotNull);
    expect(families.families.firstWhere((f) => f.id == 'f-empty').deletedAt, isNotNull);
  });
}
