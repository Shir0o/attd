import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_tracker/core/design/app_theme.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/hub/presentation/hub_attendance_view.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';

import '../../../helpers/mocks.dart';

/// Insights was removed in favour of "Who to check on": the event card has no
/// attendance-rate strip and the event menu has no View Insights item.
DateTime _week(int i) => DateTime(2026, 1, 7).add(Duration(days: 7 * i));

final _alice = Member(id: 'm1', displayName: 'Alice Okonkwo');
final _bob = Member(id: 'm2', displayName: 'Bob Castellanos');

Event _event() => Event(
      id: 'e1',
      title: 'Wednesday Study',
      time: const TimeOfDay(hour: 19, minute: 0),
      frequency: 'Weekly',
      repeatingDays: const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ],
      memberIds: const ['m1', 'm2'],
      createdAt: DateTime(2026, 1, 1),
    );

List<Session> _history() => [
      for (var i = 0; i < 8; i++)
        Session(
          id: 's$i',
          eventId: 'e1',
          title: 'Wednesday Study',
          sessionDate: _week(i),
          records: [
            SessionRecord(
              memberId: 'm1',
              attendee: 'Alice Okonkwo',
              status: AttendanceStatus.present,
              recordedAt: _week(i),
              recordedBy: 'user',
            ),
            SessionRecord(
              memberId: 'm2',
              attendee: 'Bob Castellanos',
              status:
                  i.isEven ? AttendanceStatus.present : AttendanceStatus.absent,
              recordedAt: _week(i),
              recordedBy: 'user',
            ),
          ],
          createdAt: _week(i),
          updatedAt: _week(i),
          createdBy: 'user',
        ),
    ];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late MockSessionRepository sessionRepo;
  late MockEventRepository eventRepo;
  late MockAttendanceRepository attendanceRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sessionRepo = MockSessionRepository()..setSessions(_history());
    eventRepo = MockEventRepository()..emit([_event()]);
    attendanceRepo = MockAttendanceRepository();
    attendanceRepo.setFamilies([
      Family(id: 'f1', displayName: 'Okonkwo', members: [_alice, _bob]),
    ]);
  });

  Future<void> pumpHub(
    WidgetTester tester, {
    List<Session>? history,
  }) async {
    final sessions = history ?? _history();
    sessionRepo.setSessions(sessions);
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: HubAttendanceView(
          themeController: ThemeController(prefs),
          sessionRepository: sessionRepo,
          eventRepository: eventRepo,
          attendanceRepository: attendanceRepo,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    sessionRepo.emit(sessions);
    eventRepo.emit([_event()]);
    await tester.pumpAndSettle();
  }

  testWidgets('the event card has no attendance-rate strip', (tester) async {
    await pumpHub(tester);

    expect(find.text('Wednesday Study'), findsWidgets);
    expect(find.textContaining('over 8 sessions'), findsNothing);
    expect(find.textContaining('% over'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('View insights')), findsNothing);
  });

  testWidgets('the event menu has View History but no View Insights',
      (tester) async {
    await pumpHub(tester);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();

    expect(find.text('View History'), findsOneWidget);
    expect(find.text('View Insights'), findsNothing);
    expect(find.byIcon(Icons.insights_outlined), findsNothing);
  });
}
