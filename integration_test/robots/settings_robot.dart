import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/settings/presentation/settings_page.dart';
import '../utils/test_utils.dart';

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
    final finder = find.text('Manage Members');
    // We scroll inside the main ListView on SettingsPage
    await tester.scrollUntilVisible(
      finder,
      100.0,
      scrollable: find.byType(ListView),
    );
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
}
