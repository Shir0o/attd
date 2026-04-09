import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/test_utils.dart';

class EventRobot {
  const EventRobot(this.tester);

  final WidgetTester tester;

  Future<void> enterName(String name) async {
    print('DEBUG: Entering text "$name"');
    final finder = find.byType(TextField).first;
    await tester.pumpUntilFound(finder);
    await tester.enterText(finder, name);
    await tester.pump();
  }

  Future<void> selectFrequency(String frequency) async {
    print('DEBUG: selectFrequency($frequency)');
    final dropdownFinder = find.byType(DropdownButton<String>);
    await tester.pumpUntilFound(dropdownFinder);
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    final itemFinder = find.text(frequency).last;
    await tester.tap(itemFinder);
    await tester.pumpAndSettle();
  }

  Future<void> selectDay(String day) async {
    print('DEBUG: selectDay($day)');
    final label = day.substring(0, 1).toUpperCase();
    final textFinder = find.text(label).first;
    await tester.pumpUntilFound(textFinder);
    
    final containerFinder = find.ancestor(of: textFinder, matching: find.byType(Container)).first;
    final container = tester.widget<Container>(containerFinder);
    final decoration = container.decoration as BoxDecoration;
    
    // Check if it's already selected by color (primary vs surfaceContainerLow)
    final colorScheme = Theme.of(tester.element(containerFinder)).colorScheme;
    final isSelected = decoration.color == colorScheme.primary;
    
    if (!isSelected) {
      print('DEBUG: Day $day not selected, tapping');
      final gestureFinder = find.ancestor(of: textFinder, matching: find.byType(GestureDetector)).first;
      await tester.tap(gestureFinder);
      await tester.pumpAndSettle();
    } else {
      print('DEBUG: Day $day already selected, skipping tap');
    }
  }

  Future<void> save() async {
    print('DEBUG: robot save()');
    final finder = find.byKey(const ValueKey('save_event_button'));
    await tester.pumpUntilFound(finder);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> update() async {
    print('DEBUG: robot update()');
    final finder = find.byKey(const ValueKey('save_event_button'));
    await tester.pumpUntilFound(finder);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
}
