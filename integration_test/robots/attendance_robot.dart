import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/attendance/presentation/swipeable_card.dart';

import '../utils/test_utils.dart';

class AttendanceRobot {
  const AttendanceRobot(this.tester);

  final WidgetTester tester;

  Future<void> markPresent() async {
    print('DEBUG: markPresent');
    final finder = find.byKey(const Key('presentButton'));
    await tester.pumpUntilFound(finder);
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> markAbsent() async {
    print('DEBUG: markAbsent');
    final finder = find.byKey(const Key('absentButton'));
    await tester.pumpUntilFound(finder);
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> swipeRight() async {
    print('DEBUG: swipeRight');
    final cardFinder = find.byType(SwipeableCard);
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> swipeLeft() async {
    print('DEBUG: swipeLeft');
    final cardFinder = find.byType(SwipeableCard);
    await tester.drag(cardFinder, const Offset(-500, 0));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> verifyDeckComplete() async {
    print('DEBUG: verifyDeckComplete');
    await tester.pumpUntilFound(find.text('Finalize Report'));
  }

  Future<void> verifyMemberStatus(String memberName, String status) async {
    print('DEBUG: verifyMemberStatus($memberName, $status)');
    final memberFinder = find.text(memberName);
    await tester.pumpUntilFound(memberFinder);
    expect(memberFinder, findsOneWidget);
  }

  Future<void> finishSession() async {
    print('DEBUG: finishSession');
    final button = find.text('Finalize Report');
    await tester.pumpUntilFound(button);
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 500));
  }
}
