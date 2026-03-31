import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/hub/presentation/members_page.dart';

import '../utils/test_utils.dart';

class MembersRobot {
  const MembersRobot(this.tester);

  final WidgetTester tester;

  Future<void> addMember(String memberName) async {
    print('DEBUG: addMember($memberName)');
    final membersPage = find.byType(MembersPage);
    await tester.pumpUntilFound(membersPage);

    final textField = find.byKey(const ValueKey('member_search_field'));
    await tester.enterText(textField, memberName);
    await tester.pump(const Duration(milliseconds: 500));

    final fabFinder = find.byKey(const ValueKey('member_add_fab'));
    await tester.pumpUntilFound(fabFinder);
    await tester.tap(fabFinder.last);
    await tester.pump(const Duration(milliseconds: 800));
  }

  Future<void> search(String query) async {
    print('DEBUG: search($query)');
    final textField = find.byKey(const ValueKey('member_search_field'));
    await tester.tap(textField);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(textField, query);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
  }

  Future<void> clearSearch() async {
    print('DEBUG: clearSearch');
    final textField = find.byKey(const ValueKey('member_search_field'));
    await tester.enterText(textField, '');
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> toggleMember(String memberName) async {
    print('DEBUG: toggleMember($memberName)');
    final memberFinder = find.text(memberName).first;
    await tester.pumpUntilFound(memberFinder);
    await tester.tap(memberFinder);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> verifyMemberSelected(String memberName, bool isSelected) async {
    print('DEBUG: verifyMemberSelected($memberName, $isSelected)');
    final memberFinder = find.text(memberName).first;
    await tester.pumpUntilFound(memberFinder);

    final tileFinder = find.ancestor(of: memberFinder, matching: find.byType(ListTile));
    final checkboxFinder = find.descendant(of: tileFinder, matching: find.byType(Checkbox));
    
    final checkbox = tester.widget<Checkbox>(checkboxFinder);
    expect(checkbox.value, isSelected);
  }

  Future<void> verifyMember(String memberName) async {
    print('DEBUG: verifyMember($memberName)');
    await tester.pumpUntilFound(find.text(memberName).first);
  }

  Future<void> tapEditMember(String memberName) async {
    print('DEBUG: tapEditMember($memberName)');
    final memberFinder = find.text(memberName).first;
    await tester.pumpUntilFound(memberFinder);
    
    final tileFinder = find.ancestor(of: memberFinder, matching: find.byType(ListTile));
    final editButton = find.descendant(of: tileFinder, matching: find.byIcon(Icons.edit_outlined));
    
    await tester.tap(editButton);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapDeleteMember(String memberName) async {
    print('DEBUG: tapDeleteMember($memberName)');
    final memberFinder = find.text(memberName).first;
    await tester.pumpUntilFound(memberFinder);
    
    final tileFinder = find.ancestor(of: memberFinder, matching: find.byType(ListTile));
    final deleteButton = find.descendant(of: tileFinder, matching: find.byIcon(Icons.delete_outline));
    
    await tester.tap(deleteButton);
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> handleHistoricalAlert(bool confirm) async {
    print('DEBUG: handleHistoricalAlert($confirm)');
    await tester.pumpUntilFound(find.text('Historical Data Alert'));
    await tester.tap(find.text(confirm ? 'Continue' : 'Cancel'));
    await tester.pumpAndSettle();
  }

  Future<void> handleConfirmDelete(bool confirm) async {
    print('DEBUG: handleConfirmDelete($confirm)');
    await tester.pumpUntilFound(find.text('Remove Member'));
    await tester.tap(find.text(confirm ? 'Remove' : 'Cancel'));
    await tester.pumpAndSettle();
  }

  Future<void> handleDuplicateMemberDialog(bool addAnyway) async {
    print('DEBUG: handleDuplicateMemberDialog($addAnyway)');
    await tester.pumpUntilFound(find.text('Duplicate Member'));
    await tester.tap(find.text(addAnyway ? 'Add Duplicate' : 'Cancel'));
    await tester.pumpAndSettle();
  }

  Future<void> handleHistoricalAccuracyInfo() async {
    print('DEBUG: handleHistoricalAccuracyInfo');
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpUntilFound(find.text('Historical Accuracy'));
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
  }

  // Deprecated in new flattened UI, but kept for compatibility or redirected
  Future<void> addFamily(String familyName) async => addMember(familyName);
  Future<void> verifyFamily(String familyName) async => verifyMember(familyName);
  Future<void> tapFamily(String familyName) async {
    // Do nothing as we are already on the combined page
  }
}
