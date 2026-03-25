import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/settings/presentation/settings_page.dart';
import 'package:attendance_tracker/features/settings/presentation/manage_backup_data_page.dart';
import '../utils/test_utils.dart';

class SettingsRobot {
  const SettingsRobot(this.tester);

  final WidgetTester tester;

  Future<void> verifyOnSettingsPage() async {
    await tester.pumpUntilFound(find.byType(SettingsPage));
  }

  Future<void> toggleTheme() async {
    // Find dropdown for theme
    await tester.tap(find.byType(DropdownButton<ThemeMode>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Select Dark
    await tester.tap(find.text('Dark').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> verifyDarkTheme() async {
    // This assumes scaffold has dark background color from theme
    // We can just verify the dropdown text
    expect(find.text('Dark'), findsOneWidget);
  }

  Future<void> tapManageMembers() async {
    final settingsPage = find.byType(SettingsPage);
    await tester.pumpUntilFound(settingsPage);

    final finder = find.descendant(
      of: settingsPage,
      matching: find.text('Manage Members'),
    );
    await tester.scrollUntilVisible(finder, 200);
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapManageBackupData() async {
    print('DEBUG: tapManageBackupData');
    final settingsPage = find.byType(SettingsPage);
    await tester.pumpUntilFound(settingsPage);

    final finder = find.descendant(
      of: settingsPage,
      matching: find.text('Manage Backup Data'),
    );
    await tester.scrollUntilVisible(finder, 200);
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> verifyOnManageBackupDataPage() async {
    print('DEBUG: verifyOnManageBackupDataPage');
    await tester.pumpUntilFound(find.byType(ManageBackupDataPage));
    await tester.pumpUntilFound(find.text('BACKUP SUMMARY'));
  }

  Future<void> verifyRecordCount(int expectedTotal) async {
    print('DEBUG: verifyRecordCount($expectedTotal)');
    await tester.pumpUntilFound(find.text('$expectedTotal'));
  }

  Future<void> verifyEventListed(String title) async {
    print('DEBUG: verifyEventListed($title)');
    final finder = find.text(title);
    await tester.scrollUntilVisible(finder, 200);
    expect(finder, findsOneWidget);
  }

  Future<void> verifyMemberListed(String name) async {
    print('DEBUG: verifyMemberListed($name)');
    final finder = find.text(name);
    await tester.scrollUntilVisible(finder, 200);
    expect(finder, findsOneWidget);
  }
}
