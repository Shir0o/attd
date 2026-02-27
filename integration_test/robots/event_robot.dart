import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';


class EventRobot {
  const EventRobot(this.tester);

  final WidgetTester tester;

  Future<void> enterName(String name) async {
    await tester.enterText(find.byType(TextFormField), name);
    await tester.pumpAndSettle();
  }

  Future<void> selectFrequency(String frequency) async {
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text(frequency).last);
    await tester.pumpAndSettle();
  }

  Future<void> selectDay(String dayName) async {
    // Select the circle with the day's first letter
    final letter = dayName.substring(0, 1);
    await tester.tap(find.text(letter).last); // Might be multiple 'S' or 'T'
    await tester.pumpAndSettle();
  }

  Future<void> save() async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Event').last);
    await tester.pumpAndSettle();
  }

  Future<void> update() async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes').last);
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
