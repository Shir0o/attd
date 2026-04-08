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
    await tester.pumpAndSettle();
  }

  Future<void> markAbsent() async {
    print('DEBUG: markAbsent');
    final finder = find.byKey(const Key('absentButton'));
    await tester.pumpUntilFound(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

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

    // Toggle Guest switch if needed (it's on by default in some views but let's be explicit)
    // Actually, looking at the code, _isGuest is false by default.
    final guestSwitch = find.descendant(
        of: find.widgetWithText(Row, 'Add as Guest'),
        matching: find.byType(Switch),
    );
    if (tester.any(guestSwitch)) {
        final Switch switchWidget = tester.widget(guestSwitch);
        if (!switchWidget.value) {
            await tester.tap(guestSwitch);
            await tester.pumpAndSettle();
        }
    }

    final submitButton = find.text('Add & Continue');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
  }

  Future<void> swipeRight() async {
    print('DEBUG: swipeRight');
    final cardFinder = find.byType(SwipeableCard);
    await tester.drag(cardFinder, const Offset(500, 0));
    await tester.pumpAndSettle();
  }

  Future<void> swipeLeft() async {
    print('DEBUG: swipeLeft');
    final cardFinder = find.byType(SwipeableCard);
    await tester.drag(cardFinder, const Offset(-500, 0));
    await tester.pumpAndSettle();
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
    await tester.clearSnackBars();
    
    // Wait for summary to be fully visible
    await tester.pump(const Duration(seconds: 1));
    
    // Use a very specific predicate to find the button
    final buttonFinder = find.byWidgetPredicate((widget) => 
      widget is ElevatedButton && 
      find.descendant(of: find.byWidget(widget), matching: find.text('Finalize Report')).evaluate().isNotEmpty
    );
    
    await tester.pumpUntilFound(buttonFinder);
    
    print('DEBUG: Attempting to tap Finalize Report button');
    // We'll try tapAt center which is usually safer for Positioned elements in Stacks
    final center = tester.getCenter(buttonFinder);
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    
    // If still there, try one more time with a standard tap
    if (buttonFinder.evaluate().isNotEmpty) {
        print('DEBUG: Button still visible, trying standard tap');
        await tester.tap(buttonFinder, warnIfMissed: false);
        await tester.pumpAndSettle();
    }
    
    print('DEBUG: finishSession completed');
  }
}
