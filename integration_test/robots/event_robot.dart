import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/test_utils.dart';


class EventRobot {
  const EventRobot(this.tester);

  final WidgetTester tester;

  Future<void> enterName(String name) async {
    final finder = find.byType(TextFormField);
    await tester.pumpUntilFound(finder);
    await tester.ensureVisible(finder);
    await tester.pump();
    
    print('DEBUG: Tapping name field to ensure focus');
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    
    print('DEBUG: Entering text "$name"');
    await tester.enterText(finder, name);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapTime() async {
    final timeFinder = find.text('Event Time');
    await tester.pumpUntilFound(timeFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.ancestor(of: timeFinder, matching: find.byType(GestureDetector)));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> selectTime(int hour, int minute) async {
    print('DEBUG: selectTime($hour, $minute)');
    await tapTime();
    
    final inputModeIcon = find.byIcon(Icons.keyboard_outlined);
    if (inputModeIcon.evaluate().isNotEmpty) {
      print('DEBUG: Switching to text input mode in time picker');
      await tester.tap(inputModeIcon);
      await tester.pump(const Duration(milliseconds: 500));
      
      final hourField = find.byType(TextField).first;
      final minuteField = find.byType(TextField).last;
      
      await tester.enterText(hourField, hour.toString());
      await tester.enterText(minuteField, minute.toString());
      await tester.pump(const Duration(milliseconds: 500));
    }
    
    print('DEBUG: Tapping OK on time picker');
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> selectFrequency(String frequency) async {
    print('DEBUG: selectFrequency($frequency)');
    final dropdownFinder = find.byIcon(Icons.arrow_drop_down);
    await tester.pumpUntilFound(dropdownFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(dropdownFinder);
    await tester.tap(dropdownFinder);
    await tester.pump(const Duration(milliseconds: 500));
    
    final itemFinder = find.text(frequency).last;
    await tester.pumpUntilFound(itemFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(itemFinder);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapDate() async {
    print('DEBUG: tapDate');
    final dateFinder = find.text('Date');
    await tester.pumpUntilFound(dateFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.ancestor(of: dateFinder, matching: find.byType(GestureDetector)));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> selectDate(int day) async {
    print('DEBUG: selectDate($day)');
    await tapDate();
    final dayFinder = find.text(day.toString());
    await tester.tap(dayFinder);
    await tester.pump(const Duration(milliseconds: 500));
    print('DEBUG: Tapping OK on date picker');
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> selectDay(String dayName) async {
    print('DEBUG: selectDay($dayName)');
    final letter = dayName.substring(0, 1);
    final letterFinder = find.text(letter);
    await tester.pumpUntilFound(letterFinder);
    await tester.tap(letterFinder.last); 
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> save() async {
    print('DEBUG: robot save()');
    final buttonFinder = find.byKey(const ValueKey('save_event_button'));
    await tester.pumpUntilFound(buttonFinder);
    await tester.tap(buttonFinder.last);
    await tester.pump(const Duration(milliseconds: 800));
  }

  Future<void> update() async {
    print('DEBUG: robot update()');
    final buttonFinder = find.byKey(const ValueKey('save_event_button'));
    await tester.pumpUntilFound(buttonFinder);
    await tester.tap(buttonFinder.last);
    await tester.pump(const Duration(milliseconds: 800));
  }

  Future<void> delete() async {
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump(const Duration(milliseconds: 500));
    // Confirm dialog
    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 500));
  }
}
