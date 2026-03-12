import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/sessions/presentation/event_history_page.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';

import '../../helpers/mocks.dart';
import '../../helpers/tolerant_comparator.dart';

void main() {
  late MockSessionRepository mockSessionRepository;
  late MockAttendanceRepository mockAttendanceRepository;

  setUp(() {
    mockSessionRepository = MockSessionRepository();
    mockAttendanceRepository = MockAttendanceRepository();
  });

  Widget buildEventHistoryPage({required Event event}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: EventHistoryPage(
        event: event,
        sessionRepository: mockSessionRepository,
        attendanceRepository: mockAttendanceRepository,
      ),
    );
  }

  void setScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    setupTolerantComparator('event_history_golden_test.dart', precisionError: 0.05);
  }

  final stableDate = DateTime(2023, 11, 1);

  testWidgets('EventHistoryPage Golden Test - List of Sessions', (tester) async {
    setScreenSize(tester);
    final event = Event(
      id: 'event-1',
      title: 'Weekly Sync',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'Weekly',
      createdAt: stableDate,
    );

    final session1 = Session(
      id: 'session-1',
      title: 'Weekly Sync',
      sessionDate: DateTime(2023, 10, 20),
      records: [
        SessionRecord(attendee: 'A', status: AttendanceStatus.present, recordedAt: stableDate, recordedBy: 'User'),
        SessionRecord(attendee: 'B', status: AttendanceStatus.absent, recordedAt: stableDate, recordedBy: 'User'),
      ],
      createdAt: stableDate,
      updatedAt: stableDate,
      createdBy: 'User',
      currentVersion: 1,
    );

    final session2 = Session(
      id: 'session-2',
      title: 'Weekly Sync',
      sessionDate: DateTime(2023, 10, 13),
      records: [
        SessionRecord(attendee: 'A', status: AttendanceStatus.present, recordedAt: stableDate, recordedBy: 'User'),
        SessionRecord(attendee: 'B', status: AttendanceStatus.present, recordedAt: stableDate, recordedBy: 'User'),
      ],
      createdAt: stableDate,
      updatedAt: stableDate,
      createdBy: 'User',
      currentVersion: 1,
    );

    mockSessionRepository.emit([session1, session2]);
    mockSessionRepository.setSessions([session1, session2]);

    await tester.pumpWidget(buildEventHistoryPage(event: event));

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(EventHistoryPage),
      matchesGoldenFile('goldens/event_history_list.png'),
    );
  });

  testWidgets('EventHistoryPage Golden Test - Empty History', (tester) async {
    setScreenSize(tester);
    final event = Event(
      id: 'event-2',
      title: 'New Event',
      time: const TimeOfDay(hour: 12, minute: 0),
      frequency: 'One-time',
      createdAt: DateTime.now(),
    );

    mockSessionRepository.emit([]);
    mockSessionRepository.setSessions([]);

    await tester.pumpWidget(buildEventHistoryPage(event: event));

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(EventHistoryPage),
      matchesGoldenFile('goldens/event_history_empty.png'),
    );
  });
}
