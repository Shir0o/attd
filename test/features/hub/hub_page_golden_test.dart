import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/hub/presentation/hub_page.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../helpers/mocks.dart';
import '../../helpers/tolerant_comparator.dart';

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

  final fixedDate = DateTime(2025, 6, 2); // A Monday

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
      home: TickerMode(
        enabled: false,
        child: HubPage(
          sessionRepository: mockSessionRepository,
          eventRepository: mockEventRepository,
          attendanceRepository: mockAttendanceRepository,
          themeController: themeController,
          now: fixedDate,
        ),
      ),
    );
  }

  void setScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    setupTolerantComparator('hub_page_golden_test.dart', precisionError: 0.05);
  }

  testWidgets('HubPage Golden Test - Loading State', (tester) async {
    setScreenSize(tester);
    await tester.pumpWidget(buildHubPage());
    await tester.pump(); // Capture loading indicator

    await expectLater(
      find.byType(HubPage),
      matchesGoldenFile('goldens/hub_page_loading.png'),
    );
  });

  testWidgets('HubPage Golden Test - Empty State', (tester) async {
    setScreenSize(tester);
    await tester.pumpWidget(buildHubPage());

    mockEventRepository.emit([]);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HubPage),
      matchesGoldenFile('goldens/hub_page_empty.png'),
    );
  });

  testWidgets('HubPage Golden Test - Populated State', (tester) async {
    setScreenSize(tester);
    await tester.pumpWidget(buildHubPage());

    final now = fixedDate;
    final todayWeekday = DateFormat('EEEE').format(now);
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowWeekday = DateFormat('EEEE').format(tomorrow);

    final eventToday = Event(
      id: '1',
      title: 'Morning Standup',
      time: const TimeOfDay(hour: 9, minute: 0),
      frequency: 'Weekly',
      repeatingDays: [todayWeekday],
      createdAt: now,
    );

    final eventTomorrow = Event(
      id: '2',
      title: 'Design Review',
      time: const TimeOfDay(hour: 14, minute: 30),
      frequency: 'Weekly',
      repeatingDays: [tomorrowWeekday],
      createdAt: now,
    );

    mockEventRepository.emit([eventToday, eventTomorrow]);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(HubPage),
      matchesGoldenFile('goldens/hub_page_populated.png'),
    );
  });
}
