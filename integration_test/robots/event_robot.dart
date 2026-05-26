import 'package:attendance_tracker/core/design/widgets/conv_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/test_utils.dart';

class EventRobot {
  const EventRobot(this.tester);

  final WidgetTester tester;

  Future<void> enterName(String name) async {
    print('DEBUG: Entering text "$name"');
    // TextFormField wraps a TextField internally; either works.
    final finder = find.byType(TextField).first;
    await tester.pumpUntilFound(finder);
    await tester.enterText(finder, name);
    await tester.pump();
  }

  Future<void> selectFrequency(String frequency) async {
    print('DEBUG: selectFrequency($frequency)');
    // The frequency picker is now a tappable ConvCardSoft tile that opens
    // a bottom sheet listing the four options.
    final frequencies = ['One-time', 'Weekly', 'Bi-weekly', 'Monthly'];
    final currentLabel = frequencies.firstWhere(
      (f) => find.text(f).evaluate().isNotEmpty,
      orElse: () => 'Weekly',
    );
    final tileFinder = find.text(currentLabel).last;
    await tester.pumpUntilFound(tileFinder);
    await tester.tap(tileFinder);
    await tester.pumpAndSettle();

    // Pick the requested option from the sheet.
    final itemFinder = find.text(frequency).last;
    await tester.tap(itemFinder);
    await tester.pumpAndSettle();
  }

  Future<void> selectDay(String day) async {
    print('DEBUG: selectDay($day)');
    final label = day.substring(0, 1).toUpperCase();
    final textFinder = find.text(label).first;
    await tester.pumpUntilFound(textFinder);

    // Find the enclosing ConvDayChip; its `active` flag tells us whether
    // the day is already selected.
    final chipFinder =
        find.ancestor(of: textFinder, matching: find.byType(ConvDayChip)).first;
    final chip = tester.widget<ConvDayChip>(chipFinder);

    if (!chip.active) {
      print('DEBUG: Day $day not selected, tapping');
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();
    } else {
      print('DEBUG: Day $day already selected, skipping tap');
    }
  }

  Future<void> selectTime(int hour, int minute) async {
    print('DEBUG: selectTime($hour:$minute)');
    final timeFinder = find.byIcon(Icons.schedule);
    await tester.pumpUntilFound(timeFinder);
    // The time tile is now a ConvCardSoft wrapping the schedule icon.
    await tester.tap(timeFinder);
    await tester.pumpAndSettle();

    // Try to find the hour text.
    // Note: Some pickers use "12" for 0, some use "00".
    final hourStr = hour == 0 ? '12' : hour.toString();
    final hourFinder = find.text(hourStr);
    
    if (hourFinder.evaluate().isNotEmpty) {
      await tester.tap(hourFinder.last);
      await tester.pumpAndSettle();
    }
    
    final okFinder = find.text('OK');
    if (okFinder.evaluate().isNotEmpty) {
      await tester.tap(okFinder);
    } else {
      final doneFinder = find.text('DONE');
      if (doneFinder.evaluate().isNotEmpty) {
        await tester.tap(doneFinder);
      }
    }
    await tester.pumpAndSettle();
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
