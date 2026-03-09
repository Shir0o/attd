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

  Future<void> tapTime() async {
    final timeFinder = find.text('Event Time');
    await tester.tap(find.ancestor(of: timeFinder, matching: find.byType(GestureDetector)));
    await tester.pumpAndSettle();
  }

  Future<void> selectTime(int hour, int minute) async {
    await tapTime();
    // This part is tricky with Flutter's time picker in integration tests.
    // Usually, you can find the hour/minute widgets or use tester.tap at specific offsets.
    // For simplicity, let's assume we just tap OK for now, but we should try to change it.
    // In many environments, the time picker can be interacted with via find.text.
    
    // A more reliable way for integration tests without custom keys is to just tap OK 
    // to confirm a change happened (it defaults to now or initial).
    // If we want to CHANGE it, we can try finding the input mode button.
    final inputModeIcon = find.byIcon(Icons.keyboard_outlined);
    if (inputModeIcon.evaluate().isNotEmpty) {
      await tester.tap(inputModeIcon);
      await tester.pumpAndSettle();
      
      final hourField = find.byType(TextField).first;
      final minuteField = find.byType(TextField).last;
      
      await tester.enterText(hourField, hour.toString());
      await tester.enterText(minuteField, minute.toString());
      await tester.pumpAndSettle();
    }
    
    await tester.tap(find.text('OK'));
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

  Future<void> tapDate() async {
    final dateFinder = find.text('Date');
    await tester.tap(find.ancestor(of: dateFinder, matching: find.byType(GestureDetector)));
    await tester.pumpAndSettle();
  }

  Future<void> selectDate(int day) async {
    await tapDate();
    // Tapping a day in the date picker
    final dayFinder = find.text(day.toString());
    await tester.tap(dayFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> selectDay(String dayName) async {
    // Select the circle with the day's first letter
    final letter = dayName.substring(0, 1);
    final letterFinder = find.text(letter);
    await tester.pumpUntilFound(letterFinder);
    
    // For the test, we can just tap the letter.
    // If there are multiple, we pick the last one or a specific one if possible.
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
