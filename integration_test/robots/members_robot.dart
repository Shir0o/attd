import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/hub/presentation/members_page.dart';

import '../utils/test_utils.dart';

class MembersRobot {
  const MembersRobot(this.tester);

  final WidgetTester tester;

  Future<void> addMember(String memberName) async {
    final membersPage = find.byType(MembersPage);
    await tester.pumpUntilFound(membersPage);

    // In the new MembersPage, we use the Quick Add field
    final textField = find.descendant(of: membersPage, matching: find.byType(TextField)).last;
    await tester.enterText(textField, memberName);
    await tester.pumpAndSettle();

    // Tap the FAB next to the TextField
    final fabFinder = find.byKey(const ValueKey('member_add_fab'));
    await tester.ensureVisible(fabFinder);
    await tester.tap(fabFinder);
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
}
