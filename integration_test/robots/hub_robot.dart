import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/hub/presentation/hub_attendance_view.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_start_mode.dart';

import '../utils/test_utils.dart';

class HubRobot {
  const HubRobot(this.tester);

  final WidgetTester tester;

  Future<void> verifyOnHubPage() async {
    print('DEBUG: verifyOnHubPage');
    await tester.pumpUntilFound(find.byType(HubAttendanceView));
  }

  Future<void> tapFab() async {
    print('DEBUG: HubRobot.tapFab() start');
    final fabFinder = find.byKey(const ValueKey('hub_fab'));
    await tester.pumpUntilFound(fabFinder);

    // Ensure visibility before tapping
    await tester.ensureVisible(fabFinder);
    await tester.pump(const Duration(milliseconds: 300));

    print('DEBUG: Tapping FAB');
    await tester.tap(fabFinder);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify we have navigated to AddEventPage
    await tester.pumpUntilFound(find.text('NEW EVENT'));
    print('DEBUG: Successfully navigated to AddEventPage');
  }

  Future<void> tapSettings() async {
    print('DEBUG: tapSettings');
    final finder = find.byIcon(Icons.settings);
    await tester.pumpUntilFound(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> verifyEventCard(String title) async {
    print('DEBUG: verifyEventCard($title)');
    await tester.pumpUntilFound(find.text(title));
  }

  /// Taps an event card and selects a specific start mode in the picker.
  Future<void> tapEventCardWithMode(
    String title,
    AttendanceStartMode mode,
  ) async {
    print('DEBUG: tapEventCardWithMode($title, ${mode.name})');
    await tapEventCard(title, autoConfirmStartMode: false);

    final tile = find.byKey(ValueKey('start_mode_${mode.name}'));
    await tester.pumpUntilFound(tile);
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 200));

    final confirm = find.byKey(const Key('startModeConfirmButton'));
    await tester.tap(confirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  }

  Future<void> tapEventCard(
    String title, {
    bool autoConfirmStartMode = true,
  }) async {
    print('DEBUG: tapEventCard($title)');
    final textFinder = find.text(title).last;
    await tester.pumpUntilFound(textFinder);
    await tester.ensureVisible(textFinder);
    await tester.pumpAndSettle();

    final cardFinder = find.ancestor(
      of: textFinder,
      matching: find.byType(InkWell),
    ).last;

    // Check if there is a 'Start' button
    final startButtonFinder = find.descendant(
      of: cardFinder,
      matching: find.text('Start'),
    );

    if (startButtonFinder.evaluate().isNotEmpty) {
      print('DEBUG: Found Start button, tapping it');
      await tester.tap(startButtonFinder.last);
    } else {
      print('DEBUG: No Start button, performing tap on card');
      await tester.tap(cardFinder);
    }
    
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    // The first time attendance is taken for an event, a one-time "Group
    // roster by" prompt appears before the start-mode picker. Confirm its
    // default so the flow proceeds.
    final groupingButton = find.byKey(const Key('groupingConfirmButton'));
    if (groupingButton.evaluate().isNotEmpty) {
      print('DEBUG: grouping preset prompt present, confirming');
      await tester.tap(groupingButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
    }

    // Starting a new session opens the "Start mode" picker. Auto-confirm
    // the default so existing scenarios that expected an immediate jump
    // into attendance continue to work.
    final startModeButton = find.byKey(const Key('startModeConfirmButton'));
    if (autoConfirmStartMode && startModeButton.evaluate().isNotEmpty) {
      print('DEBUG: start mode picker present, confirming');
      await tester.tap(startModeButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapEventMenu(String title) async {
    print('DEBUG: tapEventMenu($title)');
    final textFinder = find.text(title).last;
    await tester.pumpUntilFound(textFinder);
    
    // Ensure the event card is visible
    await tester.ensureVisible(textFinder);
    await tester.pumpAndSettle();

    final cardFinder = find.ancestor(
      of: textFinder,
      matching: find.byType(InkWell),
    );

    await tester.pumpUntilFound(cardFinder);

    final menuFinder = find.descendant(
      of: cardFinder.last,
      matching: find.byIcon(Icons.more_vert),
    );
    
    await tester.pumpUntilFound(menuFinder);
    await tester.tap(menuFinder.last);
    
    await tester.pumpAndSettle();
  }

  Future<void> selectMenuOption(String option) async {
    print('DEBUG: selectMenuOption($option)');
    final finder = find.text(option);
    await tester.pumpUntilFound(finder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(finder.last);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> verifyEventStatus(String title, String status) async {
    print('DEBUG: verifyEventStatus($title, $status)');
    final textFinder = find.text(title).last;
    await tester.pumpUntilFound(textFinder);

    final cardFinder = find.ancestor(
      of: textFinder,
      matching: find.byType(InkWell),
    ).last;

    // Case-insensitive matching to handle both 'Start' and 'START'
    final statusFinder = find.descendant(
      of: cardFinder,
      matching: find.textContaining(RegExp(status, caseSensitive: false)),
    );

    await tester.pumpUntilFound(statusFinder);
    expect(statusFinder, findsWidgets);
  }

  Future<void> goBack() async {
    print('DEBUG: HubRobot.goBack');
    final backButton = find.byType(BackButton);
    if (backButton.evaluate().isNotEmpty) {
      await tester.tap(backButton.last);
    } else {
      final iconBack = find.byIcon(Icons.arrow_back);
      if (iconBack.evaluate().isNotEmpty) {
        await tester.tap(iconBack.last);
      } else {
        print('DEBUG: No back button found, attempting system back');
        await tester.pageBack();
      }
    }
    await tester.pumpAndSettle();
  }
}
