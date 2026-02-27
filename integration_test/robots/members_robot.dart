import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/test_utils.dart';

class MembersRobot {
  const MembersRobot(this.tester);

  final WidgetTester tester;

  Future<void> addFamily(String familyName) async {
    // Tap Add Family
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Enter Name
    await tester.enterText(find.byType(TextField), familyName);
    await tester.pumpAndSettle();

    // Confirm
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
  }

  Future<void> verifyFamily(String familyName) async {
    await tester.pumpUntilFound(find.text(familyName));
  }

  Future<void> tapFamily(String familyName) async {
    await tester.tap(find.text(familyName));
    await tester.pumpAndSettle();
  }

  Future<void> addMember(String memberName) async {
    // Tap Add Member
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Enter Name
    await tester.enterText(find.byType(TextField), memberName);
    await tester.pumpAndSettle();

    // Confirm
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
  }

  Future<void> verifyMember(String memberName) async {
    await tester.pumpUntilFound(find.text(memberName));
  }
}
