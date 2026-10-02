import 'dart:async';

import 'package:attendance_tracker/core/design/app_theme.dart';
import 'package:attendance_tracker/core/design/widgets/conv_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const from = Rect.fromLTWH(40, 500, 160, 52);
  const to = Rect.fromLTWH(200, 100, 120, 64);
  final shuttle = find.byKey(convLandingShuttleKey);

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );
    return tester.element(find.byType(Scaffold));
  }

  testWidgets('holds at the source until the target is known, then lands',
      (tester) async {
    final context = await pumpHost(tester);
    final target = Completer<Rect Function()?>();
    var landed = false;
    showConvLandingFlight(
      context: context,
      from: from,
      target: target.future,
      color: Colors.purple,
      label: const Text('Add to roster'),
    ).then((_) => landed = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(shuttle), from);

    target.complete(() => to);
    await tester.pump(); // the flight starts
    await tester.pump(); // its first tick
    await tester.pump(const Duration(milliseconds: 100));
    final mid = tester.getRect(shuttle);
    expect(mid, isNot(from));
    expect(mid, isNot(to));
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(
              of: find.text('Add to roster'),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      lessThan(1),
    );

    await tester.pumpAndSettle();
    expect(shuttle, findsNothing);
    expect(landed, isTrue);
  });

  testWidgets('a null target removes the shuttle without flying',
      (tester) async {
    final context = await pumpHost(tester);
    var done = false;
    showConvLandingFlight(
      context: context,
      from: from,
      target: Future.value(),
      color: Colors.purple,
    ).then((_) => done = true);
    await tester.pump();
    await tester.pump();
    expect(shuttle, findsNothing);
    expect(done, isTrue);
  });

  testWidgets('shows nothing with motion off', (tester) async {
    final context = await pumpHost(tester);
    await showConvLandingFlight(
      context: context,
      from: from,
      target: Future.value(() => to),
      color: Colors.purple,
      disableAnimations: true,
    );
    await tester.pump();
    expect(shuttle, findsNothing);
  });
}
