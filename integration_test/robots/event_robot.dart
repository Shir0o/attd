import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/test_utils.dart';


class EventRobot {
  const EventRobot(this.tester);

  final WidgetTester tester;

  Future<void> enterName(String name) async {
    final finder = find.byType(TextFormField);
    await tester.pumpUntilFound(finder);
    await tester.enterText(finder, name);
    await tester.pumpAndSettle();
  }

  Future<void> selectFrequency(String frequency) async {
    final dropdownFinder = find.byIcon(Icons.arrow_drop_down);
    await tester.pumpUntilFound(dropdownFinder);
    await tester.ensureVisible(dropdownFinder);
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();
    
    final itemFinder = find.text(frequency).last;
    await tester.pumpUntilFound(itemFinder);
    await tester.tap(itemFinder);
    await tester.pumpAndSettle();
  }

  Future<void> selectDay(String dayName) async {
    // Select the circle with the day's first letter
    final letter = dayName.substring(0, 1);
    final letterFinder = find.text(letter);
    await tester.pumpUntilFound(letterFinder);
    await tester.tap(letterFinder.last); 
    await tester.pumpAndSettle();
  }

  Future<void> save() async {
    final buttonFinder = find.byKey(const ValueKey('save_event_button'));
    await tester.pumpUntilFound(buttonFinder);
    await tester.tap(buttonFinder.last);
    await tester.pumpAndSettle();
  }

  Future<void> update() async {
    final buttonFinder = find.byKey(const ValueKey('save_event_button'));
    await tester.pumpUntilFound(buttonFinder);
    await tester.tap(buttonFinder.last);
    await tester.pumpAndSettle();
  }

  Future<void> delete() async {
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    // Confirm dialog
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
  }
}
