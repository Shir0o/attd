import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/hub/presentation/hub_page.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockSessionRepository mockSessionRepository;
  late MockEventRepository mockEventRepository;
  late MockAttendanceRepository mockAttendanceRepository;
  late ThemeController themeController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    themeController = ThemeController(prefs);
    mockSessionRepository = MockSessionRepository();
    mockEventRepository = MockEventRepository();
    mockAttendanceRepository = MockAttendanceRepository();
  });

  Widget buildHubPage() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: HubPage(
        sessionRepository: mockSessionRepository,
        eventRepository: mockEventRepository,
        attendanceRepository: mockAttendanceRepository,
        themeController: themeController,
      ),
    );
  }

  void setScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('HubPage Golden Test - Loading State', (tester) async {
    setScreenSize(tester);

    // Do NOT emit anything. Let it wait.

    await tester.pumpWidget(buildHubPage());
    // Just a pump to render initial frame
    await tester.pump();

    // Verify loading indicator is present (assuming StreamBuilder waiting shows one)
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('HubPage Golden Test - Empty State', (tester) async {
    setScreenSize(tester);

    await tester.pumpWidget(buildHubPage());

    // Emit empty list AFTER pump, so StreamBuilder receives it
    mockEventRepository.emit([]);

    await tester.pumpAndSettle();

    // Verify empty state text
    expect(find.text('No events created yet'), findsOneWidget);
  });

  testWidgets('HubPage Golden Test - Populated State', (tester) async {
    setScreenSize(tester);

    final now = DateTime.now();
    final todayWeekday = DateFormat('EEEE').format(now);
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowWeekday = DateFormat('EEEE').format(tomorrow);

    final eventToday = Event(
      id: '1',
      title: 'Morning Standup',
      time: const TimeOfDay(hour: 9, minute: 0),
      frequency: 'Weekly',
      repeatingDays: [todayWeekday],
      memberIds: [],
      createdAt: now,
    );

    final eventTomorrow = Event(
      id: '2',
      title: 'Design Review',
      time: const TimeOfDay(hour: 14, minute: 30),
      frequency: 'Weekly',
      repeatingDays: [tomorrowWeekday],
      memberIds: [],
      createdAt: now,
    );

    await tester.pumpWidget(buildHubPage());

    // Emit events AFTER pump
    mockEventRepository.emit([eventToday, eventTomorrow]);

    await tester.pumpAndSettle();

    // Verify events are displayed
    expect(find.text('Morning Standup'), findsOneWidget);
    expect(find.text('Design Review'), findsOneWidget);

    // Verify "TODAY" badge is present for today's event
    // Note: The logic for TODAY might need one or more finds.
    // If it's only on the Today event, findsOneWidget is safer if generic.
    // But let's stick to find.text('TODAY')
    expect(find.text('TODAY'), findsWidgets);
  });
}
