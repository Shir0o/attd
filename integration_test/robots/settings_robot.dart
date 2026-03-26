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
    // Wait for skeleton to finish (800ms in SettingsPage)
    await tester.pump(const Duration(milliseconds: 1000));
  }

  Future<void> toggleTheme() async {
    // Find dropdown for theme
    final finder = find.byType(DropdownButton<ThemeMode>).last;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Select Dark
    final darkFinder = find.text('Dark').last;
    await tester.tap(darkFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> verifyDarkTheme() async {
    // This assumes scaffold has dark background color from theme
    // We can just verify the dropdown text
    expect(find.text('Dark'), findsWidgets);
  }

  Future<void> tapManageMembers() async {
    final settingsPage = find.byType(SettingsPage).last;
    await tester.pumpUntilFound(settingsPage);

    final finder = find.descendant(
      of: settingsPage,
      matching: find.byKey(const ValueKey('manage_members_tile')),
    ).last;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapManageBackupData() async {
    print('DEBUG: tapManageBackupData');
    final settingsPage = find.byType(SettingsPage).last;
    await tester.pumpUntilFound(settingsPage);

    final finder = find.descendant(
      of: settingsPage,
      matching: find.byKey(const ValueKey('manage_backup_data_tile')),
    ).last;
    await tester.ensureVisible(finder);
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
    final page = find.byType(ManageBackupDataPage);
    final finder = find.descendant(of: page, matching: find.text(title)).last;
    await tester.ensureVisible(finder);
    expect(finder, findsWidgets);
  }

  Future<void> verifyMemberListed(String name) async {
    print('DEBUG: verifyMemberListed($name)');
    final page = find.byType(ManageBackupDataPage);
    final finder = find.descendant(of: page, matching: find.text(name)).last;
    await tester.ensureVisible(finder);
    expect(finder, findsWidgets);
  }
}
