import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/test_utils.dart';

class SummaryRobot {
  const SummaryRobot(this.tester);

  final WidgetTester tester;

  Future<void> verifyOnSummaryPage() async {
    await tester.pumpUntilFound(find.text('Attendance Roster'));
  }

  Future<void> verifyPresentCount(int count) async {
    // Note: This simple find might be ambiguous if present and absent counts are the same.
    // In a real robust test we'd scope this finder.
    await tester.pumpUntilFound(find.text('$count'));
  }

  Future<void> verifyAbsentCount(int count) async {
    await tester.pumpUntilFound(find.text('$count'));
  }

  Future<void> verifyMemberStatus(String memberName, {required bool isPresent}) async {
    final memberFinder = find.text(memberName);
    await tester.pumpUntilFound(memberFinder);

    // Find the row containing this member
    final rowFinder = find.ancestor(of: memberFinder, matching: find.byType(Row)).first;

    // Find the switch within that row
    final switchFinder = find.descendant(of: rowFinder, matching: find.byType(Switch));

    final Switch switchWidget = tester.widget(switchFinder);
    expect(switchWidget.value, isPresent);
  }

  Future<void> toggleMember(String memberName) async {
    final memberFinder = find.text(memberName);
    await tester.pumpUntilFound(memberFinder);
    // Tap the row (via text) to toggle
    await tester.tap(memberFinder);
    await tester.pumpAndSettle();
  }

  Future<void> finalizeReport() async {
    await tester.tap(find.text('Finalize Report'));
    await tester.pumpAndSettle();
  }

  Future<void> deleteSession() async {
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
  }
}
