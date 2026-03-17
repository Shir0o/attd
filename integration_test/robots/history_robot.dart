import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/test_utils.dart';

class HistoryRobot {
  const HistoryRobot(this.tester);

  final WidgetTester tester;

  Future<void> verifySessionCount(int count) async {
    print('DEBUG: verifySessionCount($count)');
    if (count == 0) {
      await tester.pumpUntilFound(find.text('No history found'));
    } else {
      await tester.pumpUntilFound(find.byType(Card));
      // In some cases, count might be different if filtered, but we expect exact
      expect(find.byType(Card), findsNWidgets(count));
    }
  }

  Future<void> tapSession(int index) async {
    print('DEBUG: tapSession($index)');
    final sessionCards = find.byType(Card);
    await tester.pumpUntilFound(sessionCards);
    await tester.tap(sessionCards.at(index));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> verifySummaryCounts({required int present, required int absent}) async {
    print('DEBUG: verifySummaryCounts(present: $present, absent: $absent)');
    await tester.pumpUntilFound(find.text('PRESENT'));
    expect(find.text(present.toString()), findsOneWidget);
    expect(find.text(absent.toString()), findsOneWidget);
  }

  Future<void> deleteSession() async {
    print('DEBUG: deleteSession');
    final deleteIcon = find.byIcon(Icons.delete_outline);
    await tester.pumpUntilFound(deleteIcon);
    await tester.tap(deleteIcon);
    await tester.pump(const Duration(milliseconds: 500));

    final confirmButton = find.text('Delete');
    await tester.pumpUntilFound(confirmButton);
    await tester.tap(confirmButton);
    await tester.pump(const Duration(milliseconds: 500));
  }
}
