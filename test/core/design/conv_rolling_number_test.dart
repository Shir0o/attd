import 'package:attendance_tracker/core/design/app_motion.dart';
import 'package:attendance_tracker/core/design/app_theme.dart';
import 'package:attendance_tracker/core/design/widgets/conv_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(body: Center(child: child)),
      );

  group('ConvRollingNumber', () {
    Widget number(int value, {bool disableAnimations = false}) => wrap(
          ConvRollingNumber(
            value: value,
            suffix: ' left',
            disableAnimations: disableAnimations,
          ),
        );

    /// Vertical offset (fraction of its own height) of the rolling [digit].
    double offsetOf(WidgetTester tester, String digit) => tester
        .widget<FractionalTranslation>(
          find.ancestor(
            of: find.text(digit),
            matching: find.byType(FractionalTranslation),
          ),
        )
        .translation
        .dy;

    testWidgets('shows the value and suffix as one text at rest',
        (tester) async {
      await tester.pumpWidget(number(4));
      expect(find.text('4 left'), findsOneWidget);
    });

    testWidgets('an increase rolls the new digit up from below',
        (tester) async {
      await tester.pumpWidget(number(4));
      await tester.pumpWidget(number(5));
      await tester.pump(const Duration(milliseconds: 60));

      // Both digits are on screen mid-roll, moving up.
      expect(offsetOf(tester, '4'), inExclusiveRange(-1, 0));
      expect(offsetOf(tester, '5'), inExclusiveRange(0, 1));

      await tester.pump(AppMotion.houseDuration);
      expect(find.text('5 left'), findsOneWidget);
      expect(find.text('4'), findsNothing);
    });

    testWidgets('a decrease rolls the new digit down from above',
        (tester) async {
      await tester.pumpWidget(number(4));
      await tester.pumpWidget(number(3));
      await tester.pump(const Duration(milliseconds: 60));

      expect(offsetOf(tester, '4'), inExclusiveRange(0, 1));
      expect(offsetOf(tester, '3'), inExclusiveRange(-1, 0));

      await tester.pumpAndSettle();
      expect(find.text('3 left'), findsOneWidget);
    });

    testWidgets('only the digits that change roll', (tester) async {
      await tester.pumpWidget(number(12));
      await tester.pumpWidget(number(13));
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.text('1'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('1'),
          matching: find.byType(FractionalTranslation),
        ),
        findsNothing,
      );
      expect(offsetOf(tester, '3'), inExclusiveRange(0, 1));
    });

    testWidgets('a digit that appears rolls in alone', (tester) async {
      await tester.pumpWidget(number(9));
      await tester.pumpWidget(number(10));
      await tester.pump(const Duration(milliseconds: 60));
      expect(offsetOf(tester, '1'), inExclusiveRange(0, 1));
      expect(offsetOf(tester, '0'), inExclusiveRange(0, 1));
      expect(offsetOf(tester, '9'), inExclusiveRange(-1, 0));
      await tester.pumpAndSettle();
      expect(find.text('10 left'), findsOneWidget);
    });

    testWidgets('semantics read only the new value mid-roll', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(number(4));
      await tester.pumpWidget(number(3));
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.bySemanticsLabel('3 left'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('4')), findsNothing);
      semantics.dispose();
    });

    testWidgets('snaps with the test flag', (tester) async {
      await tester.pumpWidget(number(4, disableAnimations: true));
      await tester.pumpWidget(number(3, disableAnimations: true));
      expect(find.text('3 left'), findsOneWidget);
      expect(find.byType(FractionalTranslation), findsNothing);
    });

    testWidgets('snaps with the system "Remove animations" setting',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(number(4));
      await tester.pumpWidget(number(3));
      expect(find.text('3 left'), findsOneWidget);
      expect(find.byType(FractionalTranslation), findsNothing);
    });
  });

  group('ConvProgressFill', () {
    final fill = find.byType(ConvProgressFill);

    Widget bar(double fraction, {bool disableAnimations = false}) => wrap(
          SizedBox(
            width: 200,
            height: 4,
            child: ConvProgressFill(
              fraction: fraction,
              color: Colors.purple,
              disableAnimations: disableAnimations,
            ),
          ),
        );

    double fillWidth(WidgetTester tester) => tester
        .getSize(
          find.descendant(of: fill, matching: find.byType(ColoredBox)),
        )
        .width;

    testWidgets('fills its fraction of the track at full height',
        (tester) async {
      await tester.pumpWidget(bar(0.25));
      final size = tester.getSize(
        find.descendant(of: fill, matching: find.byType(ColoredBox)),
      );
      expect(size, const Size(50, 4));
    });

    testWidgets('eases to a new fraction over the house duration',
        (tester) async {
      await tester.pumpWidget(bar(0.25));
      await tester.pumpWidget(bar(0.75));
      expect(fillWidth(tester), 50);

      await tester.pump(const Duration(milliseconds: 80));
      expect(fillWidth(tester), inExclusiveRange(50, 150));

      await tester.pump(AppMotion.houseDuration);
      expect(fillWidth(tester), 150);
    });

    testWidgets('snaps with motion off', (tester) async {
      await tester.pumpWidget(bar(0.25, disableAnimations: true));
      await tester.pumpWidget(bar(0.75, disableAnimations: true));
      expect(fillWidth(tester), 150);
    });

    testWidgets('clamps out-of-range fractions', (tester) async {
      await tester.pumpWidget(bar(1.5));
      expect(fillWidth(tester), 200);
    });
  });
}
