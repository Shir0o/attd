import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/attendance/presentation/attendance_deck_page.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/data/session.dart';

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
        // Removed custom font family
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
      Member(id: '1', displayName: 'Alice Johnson'),
      Member(id: '2', displayName: 'Bob Smith'),
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

    await expectLater(
      find.byType(AttendanceDeckPage),
      matchesGoldenFile('goldens/attendance_deck_initial.png'),
    );
  });

  testWidgets('AttendanceDeckPage Golden Test - Swipe Action (Partial)', (tester) async {
    setScreenSize(tester);
    final members = [
      Member(id: '1', displayName: 'Alice Johnson'),
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

    final cardFinder = find.byKey(const ValueKey('1'));
    expect(cardFinder, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(cardFinder));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();

    await expectLater(
      find.byType(AttendanceDeckPage),
      matchesGoldenFile('goldens/attendance_deck_swipe_right.png'),
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
