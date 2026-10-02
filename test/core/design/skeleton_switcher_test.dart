import 'package:attendance_tracker/core/design/widgets/conv_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required bool loading,
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
      body: SkeletonSwitcher(
        loading: loading,
        disableAnimations: disableAnimations,
        skeleton: const SizedBox.expand(key: Key('skeleton')),
        child: const SizedBox.expand(key: Key('content')),
      ),
    ),
  );
}

double _opacityOf(WidgetTester tester, String key) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(Key(key)),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  final skeleton = find.byKey(const Key('skeleton'));
  final content = find.byKey(const Key('content'));

  testWidgets('shows the skeleton first, opaque', (tester) async {
    await tester.pumpWidget(_host(loading: true));
    expect(skeleton, findsOneWidget);
    expect(content, findsNothing);
    expect(_opacityOf(tester, 'skeleton'), 1);
  });

  testWidgets('crossfades: both exist mid-fade, content opaque after 200 ms',
      (tester) async {
    await tester.pumpWidget(_host(loading: true));
    await tester.pumpWidget(_host(loading: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(skeleton, findsOneWidget);
    expect(content, findsOneWidget);
    expect(_opacityOf(tester, 'content'), inExclusiveRange(0, 1));
    expect(_opacityOf(tester, 'skeleton'), inExclusiveRange(0, 1));

    await tester.pump(const Duration(milliseconds: 110));
    expect(skeleton, findsNothing);
    expect(_opacityOf(tester, 'content'), 1);
  });

  testWidgets('both layers fill the space they are given', (tester) async {
    await tester.pumpWidget(_host(loading: true));
    await tester.pumpWidget(_host(loading: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final page = tester.getSize(find.byType(Scaffold));
    expect(tester.getSize(skeleton), page);
    expect(tester.getSize(content), page);
  });

  testWidgets('the disableAnimations flag swaps instantly', (tester) async {
    await tester.pumpWidget(_host(loading: true, disableAnimations: true));
    await tester.pumpWidget(_host(loading: false, disableAnimations: true));
    expect(skeleton, findsNothing);
    expect(content, findsOneWidget);
    expect(find.byType(AnimatedSwitcher), findsNothing);
  });

  testWidgets('system "Remove animations" swaps instantly', (tester) async {
    await tester.pumpWidget(_host(loading: true, systemReduceMotion: true));
    await tester.pumpWidget(_host(loading: false, systemReduceMotion: true));
    expect(skeleton, findsNothing);
    expect(content, findsOneWidget);
  });
}
