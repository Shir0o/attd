import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/test_utils.dart';

class MembersRobot {
  const MembersRobot(this.tester);

  final WidgetTester tester;

  Future<void> addMember(String memberName) async {
    // In the new MembersPage, we use the Quick Add field
    final textField = find.byType(TextField).last; // The second TextField is Quick Add
    await tester.enterText(textField, memberName);
    await tester.pumpAndSettle();

    // Tap the FAB next to the TextField
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
  }

  Future<void> verifyMember(String memberName) async {
    await tester.pumpUntilFound(find.text(memberName));
  }

  // Deprecated in new flattened UI, but kept for compatibility or redirected
  Future<void> addFamily(String familyName) async => addMember(familyName);
  Future<void> verifyFamily(String familyName) async => verifyMember(familyName);
  Future<void> tapFamily(String familyName) async {
    // Do nothing as we are already on the combined page
  }

  Future<void> toggleMemberInEvent(String memberName, {bool selected = true}) async {
    final memberFinder = find.text(memberName);
    await tester.pumpUntilFound(memberFinder);

    final rowFinder = find.ancestor(of: memberFinder, matching: find.byType(ListTile));
    final checkboxFinder = find.descendant(of: rowFinder, matching: find.byType(Checkbox));

    final Checkbox checkbox = tester.widget(checkboxFinder);
    if (checkbox.value != selected) {
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();
    }
  }
}
