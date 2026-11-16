import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/attendance/presentation/fast_marking/likely_here_view.dart';
import 'package:attendance_tracker/features/attendance/presentation/session_summary_page.dart';

import '../utils/test_utils.dart';

class AttendanceRobot {
  const AttendanceRobot(this.tester);

  final WidgetTester tester;

  /// Every name tile on the marking grid, A to Z.
  Finder get _tiles => find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('likelyHereChip_'),
      );

  /// Waits for the marking grid, which is the only way to take attendance.
  Future<void> waitForGrid() async {
    print('DEBUG: waitForGrid');
    await tester.pumpUntilFound(find.byType(LikelyHereView));
    await tester.pumpUntilFound(_tiles.first);
  }

  Future<void> verifyName(String name) async {
    print('DEBUG: verifyName($name)');
    final finder = find.text(name);
    await tester.pumpUntilFound(finder);
    expect(finder, findsWidgets);
  }

  /// Taps the [index]th tile (A to Z) to mark that person present, or to take
  /// the mark back off.
  Future<void> toggleTile(int index) async {
    print('DEBUG: toggleTile($index)');
    final tile = _tiles.at(index);
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  Future<void> addGuest(String name, {bool isPresent = true}) async {
    print('DEBUG: addGuest($name)');
    final pill = find.byKey(const Key('likelyHereAddGuest'));
    await tester.pumpUntilFound(pill);
    await tester.tap(pill);
    await tester.pumpAndSettle();

    final nameField = find.byType(TextField);
    await tester.enterText(nameField, name);
    await tester.pumpAndSettle();

    final submitButton = find.byKey(const Key('addSheetAddToRoster'));
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);

    // Wait for bottom sheet to close
    await tester.pumpAndSettle();
    await tester.pumpUntilAbsent(find.byKey(const Key('addSheetNameField')));
  }

  Future<void> verifyMemberStatus(String memberName, String status) async {
    print('DEBUG: verifyMemberStatus($memberName, $status)');
    final memberFinder = find.text(memberName);
    await tester.pumpUntilFound(memberFinder);
    expect(memberFinder, findsOneWidget);
  }

  Future<void> finishSession() async {
    print('DEBUG: finishSession');
    final messenger = ScaffoldMessenger.maybeOf(
      tester.element(find.byType(MaterialApp).first),
    );
    if (messenger != null) {
      messenger.clearSnackBars();
      await tester.pump(const Duration(milliseconds: 500));
    }

    // Check if we are already on summary page
    if (find.byType(SessionSummaryPage).evaluate().isNotEmpty) {
      print('DEBUG: Already on SessionSummaryPage, skipping tap');
      return;
    }

    // Done saves the marks and opens the summary.
    final done = find.byKey(const Key('finishSessionButton'));
    await tester.pumpUntilFound(done);

    print('DEBUG: Tapping Done');
    await tester.tap(done);
    await tester.pumpAndSettle();
    await tester.pumpUntilFound(find.byType(SessionSummaryPage));

    // Extra pump for SessionSummaryPage skeleton
    await tester.pump(const Duration(milliseconds: 1000));
    print('DEBUG: finishSession completed');
  }
}
