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
      // In EventHistoryPage, we look for cards or list items
      await tester.pumpUntilFound(find.byType(Card));
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
    // Wait for numbers to populate if they are in AnimatedSwitcher or similar
    await tester.pump(const Duration(milliseconds: 500));
    
    expect(find.text(present.toString()), findsWidgets);
    expect(find.text(absent.toString()), findsWidgets);
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
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
  }
}
