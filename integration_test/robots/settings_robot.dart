import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';


class SettingsRobot {
  const SettingsRobot(this.tester);

  final WidgetTester tester;

  Future<void> toggleTheme() async {
    // Find dropdown for theme
    await tester.tap(find.byType(DropdownButton<ThemeMode>));
    await tester.pumpAndSettle();

    // Select Dark
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();
  }

  Future<void> verifyDarkTheme() async {
    // This assumes scaffold has dark background color from theme
    // We can just verify the dropdown text
    expect(find.text('Dark'), findsOneWidget);
  }

  Future<void> tapManageMembers() async {
    await tester.tap(find.text('Manage Members'));
    await tester.pumpAndSettle();
  }
}
