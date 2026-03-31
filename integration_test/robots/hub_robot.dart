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
    print('DEBUG: HubRobot.tapFab() start');
    final fabFinder = find.byKey(const ValueKey('hub_fab'));
    await tester.pumpUntilFound(fabFinder);

    // Ensure visibility before tapping
    await tester.ensureVisible(fabFinder);
    await tester.pump(const Duration(milliseconds: 300));

    print('DEBUG: Tapping FAB');
    // Enforce uniqueness to ensure we're hitting the intended button
    await tester.tap(fabFinder);

    // Use pump and pumpUntilFound instead of pumpAndSettle which can hang
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify we have navigated to AddEventPage
    await tester.pumpUntilFound(find.text('New Event'));
    print('DEBUG: Successfully navigated to AddEventPage');  }

  Future<void> tapSettings() async {
    print('DEBUG: tapSettings');
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
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapEventMenu(String title) async {
    final textFinder = find.text(title);
    await tester.pumpUntilFound(textFinder);
    await tester.pump(const Duration(milliseconds: 300));

    final cardFinder = find.ancestor(
      of: textFinder,
      matching: find.byType(Card),
    );
    final menuFinder = find.descendant(
      of: cardFinder,
      matching: find.byIcon(Icons.more_vert),
    );

    await tester.tap(menuFinder);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> selectMenuOption(String option) async {
    final finder = find.text(option);
    await tester.pumpUntilFound(finder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> verifyEventStatus(String title, String status) async {
    print('DEBUG: verifyEventStatus($title, $status)');
    final textFinder = find.text(title);
    await tester.pumpUntilFound(textFinder);

    final cardFinder = find.ancestor(
      of: textFinder,
      matching: find.byType(Card),
    );
    final statusFinder = find.descendant(
      of: cardFinder,
      matching: find.textContaining(status),
    );

    await tester.pumpUntilFound(statusFinder);
    expect(statusFinder, findsOneWidget);
  }

  Future<void> goBack() async {
    print('DEBUG: goBack');
    final backButton = find.byType(BackButton);
    if (backButton.evaluate().isNotEmpty) {
      await tester.tap(backButton.last);
    } else {
      await tester.tap(find.byIcon(Icons.arrow_back).last);
    }
    await tester.pumpAndSettle();
  }
}
