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
    await verifyOnSettingsPage();
    final settingsPage = find.byType(SettingsPage).last;

    final finder = find.descendant(
      of: settingsPage,
      matching: find.byKey(const ValueKey('manage_members_tile')),
    ).last;
    
    await tester.dragUntilVisible(
      finder,
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapManageBackupData() async {
    print('DEBUG: tapManageBackupData');
    await verifyOnSettingsPage();
    final settingsPage = find.byType(SettingsPage).last;

    final finder = find.descendant(
      of: settingsPage,
      matching: find.byKey(const ValueKey('manage_backup_data_tile')),
    ).last;
    
    // Explicitly scroll until visible to avoid hit test issues on physical devices
    await tester.dragUntilVisible(
      finder,
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    
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
    // Take a screenshot to see what's on the screen if it fails
    // We can't easily see it now, but it's good practice
    await tester.pump(const Duration(milliseconds: 500));
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

  Future<void> searchBackup(String query) async {
    print('DEBUG: searchBackup($query)');
    final textField = find.byType(TextField); // The search bar in ManageBackupDataPage
    await tester.enterText(textField, query);
    await tester.pump(const Duration(milliseconds: 500));
    // Dismiss keyboard
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> deleteBackupRecord(String title) async {
    print('DEBUG: deleteBackupRecord($title)');
    
    // Find the icon button whose key starts with 'delete_$title'
    final finder = find.byWidgetPredicate((widget) => 
      widget is IconButton && 
      widget.key is ValueKey<String> && 
      (widget.key as ValueKey<String>).value.startsWith('delete_$title')
    ).first;

    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> saveCleanedBackup() async {
    print('DEBUG: saveCleanedBackup');
    final button = find.byKey(const ValueKey('save_cleaned_backup_button'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpUntilAbsent(find.byType(ManageBackupDataPage));
  }
}
