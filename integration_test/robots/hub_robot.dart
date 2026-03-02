import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// No direct import of test_utils needed here if not using extension directly on tester within class methods,
// but we will use pumpUntilFound which is an extension on WidgetTester defined in test_utils.
import '../utils/test_utils.dart';

class HubRobot {
  const HubRobot(this.tester);

  final WidgetTester tester;

  Future<void> verifyOnHubPage() async {
    // Check for "TODAY" text which is prominent on Hub
    await tester.pumpUntilFound(find.text('TODAY'));
  }

  Future<void> tapFab() async {
    final fabFinder = find.byKey(const ValueKey('hub_fab'));
    await tester.pumpUntilFound(fabFinder);
    
    // Ensure the FAB is in view and settled
    await tester.ensureVisible(fabFinder);
    await tester.pumpAndSettle();
    
    await tester.tap(fabFinder);
    await tester.pumpAndSettle();
  }

  Future<void> tapSettings() async {
    final finder = find.byIcon(Icons.settings);
    await tester.pumpUntilFound(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> verifyEventCard(String title) async {
    await tester.pumpUntilFound(find.text(title));
  }

  Future<void> tapEventCard(String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Future<void> tapEventMenu(String title) async {
    // Finding the specific menu icon for a card with 'title'
    final textFinder = find.text(title);
    await tester.pumpUntilFound(textFinder);

    final cardFinder = find.ancestor(of: textFinder, matching: find.byType(Card));
    final menuFinder = find.descendant(of: cardFinder, matching: find.byIcon(Icons.more_vert));

    await tester.tap(menuFinder);
    await tester.pumpAndSettle();
  }

  Future<void> selectMenuOption(String option) async {
    // Menu options are usually in a bottom sheet or popup, just find by text
    await tester.tap(find.text(option));
    await tester.pumpAndSettle();
  }
}
