import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/test_utils.dart';

class HistoryRobot {
  const HistoryRobot(this.tester);

  final WidgetTester tester;

  Future<void> verifySessionCount(int count) async {
    print('DEBUG: verifySessionCount($count)');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
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
    final deleteButton = find.byTooltip('Delete session');
    await tester.pumpUntilFound(deleteButton);
    await tester.tap(deleteButton);
    await tester.pump(const Duration(milliseconds: 500));

    final confirmButton = find.text('Delete');
    await tester.pumpUntilFound(confirmButton);
    await tester.tap(confirmButton);
    
    // Wait for the deletion to complete and navigation to finish
    // Crucial: wait for deletion to persist and stream to emit
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
  }
}
