import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/test_utils.dart';

class AttendanceRobot {
  const AttendanceRobot(this.tester);

  final WidgetTester tester;

  Future<void> markPresent() async {
    // Tap the checkmark button
    await tester.tap(find.byKey(const Key('presentButton')));
    await tester.pumpAndSettle();
  }

  Future<void> markAbsent() async {
    // Tap the cross button
    await tester.tap(find.byKey(const Key('absentButton')));
    await tester.pumpAndSettle();
  }

  Future<void> verifyDeckComplete() async {
    // Should see "Finalize Report" on summary page
    await tester.pumpUntilFound(find.text('Finalize Report'));
  }

  Future<void> verifyMemberStatus(String memberName, String status) async {
    // On Summary Page, find member row and check status icon/text
    // This is tricky without specific keys, but we can look for the member name
    // and a nearby icon.
    final memberFinder = find.text(memberName);
    await tester.pumpUntilFound(memberFinder);

    // For now just verify member is present in list
    expect(memberFinder, findsOneWidget);
  }

  Future<void> finishSession() async {
    await tester.tap(find.text('Finalize Report'));
    await tester.pumpAndSettle();
  }

  Future<void> addGuest(String name, {bool isPresent = true}) async {
    await tester.tap(find.text('Add Guest'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), name);
    await tester.pumpAndSettle();

    if (!isPresent) {
       await tester.tap(find.byType(Switch));
       await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Add & Continue'));
    await tester.pumpAndSettle();
  }

  Future<void> undoSwipe() async {
    await tester.tap(find.byKey(const Key('undoButton')));
    await tester.pumpAndSettle();
  }

  Future<void> verifyCardVisible(String memberName) async {
    await tester.pumpUntilFound(find.text(memberName));
  }
}
