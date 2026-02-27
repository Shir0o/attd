import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/test_utils.dart';

class HistoryRobot {
  const HistoryRobot(this.tester);

  final WidgetTester tester;

  Future<void> verifyOnHistoryPage(String eventTitle) async {
    await tester.pumpUntilFound(find.text('${eventTitle.trim()} History'));
  }

  Future<void> tapSession(String dateText) async {
    await tester.tap(find.text(dateText));
    await tester.pumpAndSettle();
  }

  Future<void> verifySessionPresent(String dateText) async {
    await tester.pumpUntilFound(find.text(dateText));
  }
}
