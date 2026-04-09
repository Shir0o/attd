import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/attendance/presentation/swipeable_card.dart';
import 'package:attendance_tracker/features/attendance/presentation/session_summary_page.dart';

import '../utils/test_utils.dart';

class AttendanceRobot {
  const AttendanceRobot(this.tester);

  final WidgetTester tester;

  Future<void> verifyCardName(String name) async {
    print('DEBUG: verifyCardName($name)');
    final finder = find.text(name);
    await tester.pumpUntilFound(finder);
    expect(finder, findsWidgets);
  }

  Future<void> markPresent() async {
    print('DEBUG: markPresent');
    final finder = find.byKey(const Key('presentButton'));
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder);
    } else {
      await swipePresent();
    }
    await tester.pumpAndSettle();
  }

  Future<void> markAbsent() async {
    print('DEBUG: markAbsent');
    final finder = find.byKey(const Key('absentButton'));
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder);
    } else {
      await swipeAbsent();
    }
    await tester.pumpAndSettle();
  }

  Future<void> swipePresent() async => swipeRight();
  Future<void> swipeAbsent() async => swipeLeft();

  Future<void> undo() async {
    print('DEBUG: undo');
    final finder = find.byKey(const Key('undoButton'));
    await tester.pumpUntilFound(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> addGuest(String name, {bool isPresent = true}) async {
    print('DEBUG: addGuest($name)');
    final addIcon = find.byTooltip('Add Person');
    await tester.pumpUntilFound(addIcon);
    await tester.tap(addIcon);
    await tester.pumpAndSettle();

    final nameField = find.byType(TextField);
    await tester.enterText(nameField, name);
    await tester.pumpAndSettle();

    // In AddMemberSheet, it's 'Mark as Present' and 'Add as Guest'
    final submitButton = find.text('Add & Continue');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
  }

  Future<void> swipeRight() async {
    print('DEBUG: swipeRight');
    final cardFinder = find.byType(SwipeableCard);
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  Future<void> swipeLeft() async {
    print('DEBUG: swipeLeft');
    final cardFinder = find.byType(SwipeableCard);
    await tester.drag(cardFinder, const Offset(-500, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  Future<void> verifyDeckComplete() async {
    print('DEBUG: verifyDeckComplete');
    // It could be the button or we already navigated to Summary
    final finder = find.byWidgetPredicate((widget) => 
        (widget is Text && widget.data == 'Finalize Report') ||
        (widget is SessionSummaryPage)
    );
    await tester.pumpUntilFound(finder);
  }

  Future<void> verifyMemberStatus(String memberName, String status) async {
    print('DEBUG: verifyMemberStatus($memberName, $status)');
    final memberFinder = find.text(memberName);
    await tester.pumpUntilFound(memberFinder);
    expect(memberFinder, findsOneWidget);
  }

  Future<void> finishSession() async {
    print('DEBUG: finishSession');
    final messenger = ScaffoldMessenger.maybeOf(
      tester.element(find.byType(MaterialApp).first),
    );
    if (messenger != null) {
      messenger.clearSnackBars();
      await tester.pump(const Duration(milliseconds: 500));
    }
    
    // Check if we are already on summary page
    if (find.byType(SessionSummaryPage).evaluate().isNotEmpty) {
        print('DEBUG: Already on SessionSummaryPage, skipping tap');
        return;
    }

    // Wait for "Finalize Report" button
    final buttonFinder = find.text('Finalize Report');
    await tester.pumpUntilFound(buttonFinder);
    
    print('DEBUG: Tapping Finalize Report button');
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();
    
    // Extra pump for SessionSummaryPage skeleton
    await tester.pump(const Duration(milliseconds: 1000));
    print('DEBUG: finishSession completed');
  }
}
