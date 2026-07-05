import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/settings/presentation/settings_page.dart';
import 'package:attendance_tracker/features/settings/presentation/manage_backup_data_page.dart';
import '../utils/test_utils.dart';

class SettingsRobot {
  const SettingsRobot(this.tester);

  final WidgetTester tester;

  Future<void> verifyOnSettingsPage() async {
    print('DEBUG: verifyOnSettingsPage');
    await tester.pumpUntilFound(find.byType(SettingsPage));
    // The content is in a CustomScrollView with key 'content' after loading
    // Skeleton duration is 800ms, so we wait and pump.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpUntilFound(find.byKey(const ValueKey('content')));
    await tester.pumpAndSettle();
  }

  Future<void> toggleTheme() async {
    print('DEBUG: toggleTheme');
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
    print('DEBUG: verifyDarkTheme');
    expect(find.text('Dark'), findsWidgets);
  }

  Future<void> tapManageMembers() async {
    print('DEBUG: tapManageMembers');
    await verifyOnSettingsPage();

    final finder = find.byKey(const ValueKey('manage_members_tile'));
    await _scrollContentUntilVisible(finder);

    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
  }

  Future<void> tapManageBackupData() async {
    print('DEBUG: tapManageBackupData');
    await verifyOnSettingsPage();

    final finder = find.byKey(const ValueKey('manage_backup_data_tile'));
    await _scrollContentUntilVisible(finder);

    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
  }

  Future<void> _scrollContentUntilVisible(Finder finder) async {
    final content = find.byKey(const ValueKey('content'));
    for (var attempts = 0; attempts < 20; attempts++) {
      if (finder.evaluate().isNotEmpty) {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        return;
      }
      await tester.drag(content, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await tester.pumpUntilFound(finder);
  }

  Future<void> verifyOnManageBackupDataPage() async {
    print('DEBUG: verifyOnManageBackupDataPage');
    await tester.pumpUntilFound(find.byType(ManageBackupDataPage));
    await tester.pumpUntilFound(find.text('Storage inspector'));
  }

  Future<void> verifyRecordCount(int expectedTotal) async {
    print('DEBUG: verifyRecordCount($expectedTotal)');
    await tester.pump(const Duration(milliseconds: 1000));
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
    final textField = find.byType(TextField);
    await tester.tap(textField);
    await tester.pumpAndSettle();
    await tester.enterText(textField, query);
    await tester.pumpAndSettle();
  }

  Future<void> deleteBackupRecord(String title) async {
    print('DEBUG: deleteBackupRecord($title)');
    
    // Tap the record row to expand it
    final rowFinder = find.descendant(
      of: find.byType(ListView),
      matching: find.text(title),
    ).first;
    await tester.tap(rowFinder);
    await tester.pumpAndSettle();

    // Scroll if needed to ensure the delete button is visible
    final deleteButton = find.text('Delete record');
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    // If Historical Data Alert is shown, confirm it
    final continueBtn = find.text('Continue');
    if (continueBtn.evaluate().isNotEmpty) {
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();
    }
  }

  Future<void> saveCleanedBackup() async {
    print('DEBUG: saveCleanedBackup');
    // In the new UI, individual deletes are immediate. We just press the back button to return to Settings.
    final backButton = find.byIcon(Icons.arrow_back);
    if (backButton.evaluate().isNotEmpty) {
      await tester.tap(backButton);
    } else {
      await tester.tap(find.byType(BackButton));
    }
    await tester.pumpAndSettle();
    await tester.pumpUntilAbsent(find.byType(ManageBackupDataPage));
  }
}
