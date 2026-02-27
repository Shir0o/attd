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
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
  }

  Future<void> tapSettings() async {
    await tester.tap(find.byIcon(Icons.settings));
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
    // We look for a Card widget that contains the text 'title', then find the menu icon inside it.
    final cardFinder = find.widgetWithText(Card, title);
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
