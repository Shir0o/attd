import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/attendance/presentation/attendance_deck_page.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/features/attendance/presentation/swipeable_card.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockSessionRepository mockSessionRepository;

  setUp(() {
    mockSessionRepository = MockSessionRepository();
  });

  Widget buildAttendanceDeckPage({
    required Session session,
    required List<Member> members,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: AttendanceDeckPage(
        session: session,
        members: members,
        sessionRepository: mockSessionRepository,
      ),
    );
  }

  void setScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('AttendanceDeckPage Golden Test - Initial View', (tester) async {
    setScreenSize(tester);
    final members = [
      const Member(id: '1', displayName: 'Alice Johnson'),
      const Member(id: '2', displayName: 'Bob Smith'),
    ];

    final session = Session(
      id: 'session-1',
      title: 'Daily Standup',
      sessionDate: DateTime.now(),
      records: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
      currentVersion: 1,
    );

    await tester.pumpWidget(buildAttendanceDeckPage(
      session: session,
      members: members,
    ));

    // Wait for initial animation/loading
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verify first member card is visible
    expect(find.text('Alice Johnson'), findsOneWidget);
    // Verify swipeable card is present
    expect(find.byType(SwipeableCard), findsOneWidget);
  });

  testWidgets('AttendanceDeckPage Golden Test - Swipe Action (Partial)', (tester) async {
    setScreenSize(tester);
    final members = [
      const Member(id: '1', displayName: 'Alice Johnson'),
      const Member(id: '2', displayName: 'Bob Smith'),
    ];

    final session = Session(
      id: 'session-1',
      title: 'Daily Standup',
      sessionDate: DateTime.now(),
      records: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'User',
      currentVersion: 1,
    );

    await tester.pumpWidget(buildAttendanceDeckPage(
      session: session,
      members: members,
    ));

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final cardFinder = find.byType(SwipeableCard);
    expect(cardFinder, findsOneWidget);

    // Simulate Swipe Right (Present)
    final gesture = await tester.startGesture(tester.getCenter(cardFinder));
    await gesture.moveBy(const Offset(300, 0)); // Move far enough to trigger swipe
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Alice should be gone, Bob should appear
    expect(find.text('Alice Johnson'), findsNothing);
    expect(find.text('Bob Smith'), findsOneWidget);
  });
}
