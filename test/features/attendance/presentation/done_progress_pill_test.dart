import 'package:attendance_tracker/core/design/app_theme.dart';
import 'package:attendance_tracker/features/attendance/presentation/done_progress_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  double progress, {
  bool complete = false,
  bool solid = false,
  bool systemReduceMotion = false,
  VoidCallback? onPressed,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(disableAnimations: systemReduceMotion),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: DoneProgressPill(
          key: const Key('pill'),
          progress: progress,
          complete: complete,
          solid: solid,
          onPressed: onPressed ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  final fill = find.descendant(
    of: find.byKey(const Key('doneProgressFill')),
    matching: find.byType(ColoredBox),
  );

  testWidgets('the fill eases to a new progress', (tester) async {
    await tester.pumpWidget(_host(0));
    final w = tester.getSize(find.byKey(const Key('pill'))).width;
    await tester.pumpWidget(_host(0.5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getSize(fill).width, inExclusiveRange(0, w / 2));
    await tester.pumpAndSettle();
    expect(tester.getSize(fill).width, closeTo(w / 2, 0.01));
  });

  testWidgets('completing glows once, then settles', (tester) async {
    await tester.pumpWidget(_host(0.75));
    expect(find.byKey(doneGlowKey), findsNothing);
    await tester.pumpWidget(_host(1, complete: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(doneGlowKey), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(doneGlowKey), findsNothing);
    // Rebuilding while complete does not glow again.
    await tester.pumpWidget(_host(1, complete: true, onPressed: () {}));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(doneGlowKey), findsNothing);
  });

  testWidgets('already complete on first build does not glow', (tester) async {
    await tester.pumpWidget(_host(1, complete: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(doneGlowKey), findsNothing);
  });

  testWidgets('system "Remove animations" snaps the fill and skips the glow',
      (tester) async {
    await tester.pumpWidget(_host(0, systemReduceMotion: true));
    final w = tester.getSize(find.byKey(const Key('pill'))).width;
    await tester.pumpWidget(_host(0.5, systemReduceMotion: true));
    await tester.pump();
    expect(tester.getSize(fill).width, closeTo(w / 2, 0.01));
    await tester.pumpWidget(
      _host(1, complete: true, systemReduceMotion: true),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(doneGlowKey), findsNothing);
    expect(tester.getSize(fill).width, closeTo(w, 0.01));
  });

  testWidgets('solid mode has no fill and no glow', (tester) async {
    await tester.pumpWidget(_host(0.3, solid: true));
    expect(find.byKey(const Key('doneProgressFill')), findsNothing);
    await tester.pumpWidget(_host(1, complete: true, solid: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(doneGlowKey), findsNothing);
  });

  testWidgets('tapping calls onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(0.2, onPressed: () => taps++));
    await tester.tap(find.byKey(const Key('pill')));
    expect(taps, 1);
  });
}
