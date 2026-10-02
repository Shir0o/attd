import 'package:attendance_tracker/core/design/widgets/conv_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required int index,
  required ValueChanged<int> onChanged,
  bool disableAnimations = false,
  bool systemReduceMotion = false,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(disableAnimations: systemReduceMotion),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: ConvSegmented(
          options: const [
            ConvSegmentOption(label: 'Deck'),
            ConvSegmentOption(label: 'A much longer one'),
            ConvSegmentOption(label: 'X'),
          ],
          selectedIndex: index,
          onChanged: onChanged,
          disableAnimations: disableAnimations,
        ),
      ),
    ),
  );
}

void main() {
  final thumb = find.byKey(convSegmentedThumbKey);

  Rect segment(WidgetTester tester, String label) {
    final r = tester.getRect(
      find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
    );
    return r;
  }

  Future<void> pumpAt(
    WidgetTester tester,
    int index, {
    bool disableAnimations = false,
    bool systemReduceMotion = false,
  }) async {
    await tester.pumpWidget(
      _host(
        index: index,
        onChanged: (_) {},
        disableAnimations: disableAnimations,
        systemReduceMotion: systemReduceMotion,
      ),
    );
    // Measure, then settle.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the thumb sits behind the selected segment', (tester) async {
    await pumpAt(tester, 0);
    expect(tester.getRect(thumb), segment(tester, 'Deck'));
  });

  testWidgets('the thumb slides and resizes to the new segment over 220 ms',
      (tester) async {
    await pumpAt(tester, 0);
    final from = tester.getRect(thumb);

    await tester.pumpWidget(_host(index: 1, onChanged: (_) {}));
    await tester.pump(); // rebuild, then measure
    await tester.pump(); // thumb starts moving
    await tester.pump(const Duration(milliseconds: 80));
    final target = segment(tester, 'A much longer one');
    final mid = tester.getRect(thumb);
    expect(mid.left, inExclusiveRange(from.left, target.left));
    expect(mid.width, inExclusiveRange(from.width, target.width));

    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getRect(thumb), target);
  });

  testWidgets('tapping a segment reports its index', (tester) async {
    int? tapped;
    await tester.pumpWidget(_host(index: 0, onChanged: (i) => tapped = i));
    await tester.tap(find.text('X'));
    expect(tapped, 2);
  });

  testWidgets('with the flag set the thumb snaps', (tester) async {
    await pumpAt(tester, 0, disableAnimations: true);
    await tester.pumpWidget(
      _host(index: 2, onChanged: (_) {}, disableAnimations: true),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.getRect(thumb), segment(tester, 'X'));
  });

  testWidgets('system "Remove animations" snaps the thumb', (tester) async {
    await pumpAt(tester, 0, systemReduceMotion: true);
    await tester.pumpWidget(
      _host(index: 1, onChanged: (_) {}, systemReduceMotion: true),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.getRect(thumb), segment(tester, 'A much longer one'));
  });

  testWidgets('segments report selected state to accessibility',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAt(tester, 1);
    expect(
      tester.getSemantics(find.text('A much longer one')),
      containsSemantics(
        label: 'A much longer one',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('X')),
      containsSemantics(
        label: 'X',
        isButton: true,
        isSelected: false,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    handle.dispose();
  });
}
