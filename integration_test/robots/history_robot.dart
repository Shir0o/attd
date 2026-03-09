import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/test_utils.dart';

class HistoryRobot {
  const HistoryRobot(this.tester);

  final WidgetTester tester;

  Future<void> verifySessionCount(int count) async {
    if (count == 0) {
      await tester.pumpUntilFound(find.text('No history found'));
    } else {
      await tester.pumpUntilFound(find.byType(Card));
      expect(find.byType(Card), findsNWidgets(count));
    }
  }

  Future<void> tapSession(int index) async {
    final sessionCards = find.byType(Card);
    await tester.tap(sessionCards.at(index));
    await tester.pumpAndSettle();
  }

  Future<void> verifySummaryCounts({required int present, required int absent}) async {
    await tester.pumpUntilFound(find.text('PRESENT'));
    expect(find.text(present.toString()), findsOneWidget);
    expect(find.text(absent.toString()), findsOneWidget);
  }

  Future<void> deleteSession() async {
    final deleteIcon = find.byIcon(Icons.delete_outline);
    await tester.pumpUntilFound(deleteIcon);
    await tester.tap(deleteIcon);
    await tester.pumpAndSettle();

    final confirmButton = find.text('Delete');
    await tester.pumpUntilFound(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
  }
}
