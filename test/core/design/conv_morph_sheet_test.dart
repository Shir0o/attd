import 'package:attendance_tracker/core/design/widgets/conv_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const labelCopy = Key('labelCopy');
  final bounds = find.byKey(convMorphSheetBoundsKey);

  late GlobalKey<ConvMorphSourceState> source;
  late Future<String?> result;
  BuildContext? sheetContext;

  Widget sheet(BuildContext context) {
    sheetContext = context;
    return Container(
      height: 300,
      color: Colors.white,
      alignment: Alignment.center,
      child: TextButton(
        onPressed: () => Navigator.pop(context, 'done'),
        child: const Text('Submit'),
      ),
    );
  }

  /// A host with a violet "Open" source in the bottom-right corner. With
  /// [mountSource] false the key is never attached.
  Future<void> pumpHost(
    WidgetTester tester, {
    bool mountSource = true,
    WidgetBuilder? builder,
  }) async {
    source = GlobalKey<ConvMorphSourceState>();
    sheetContext = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomRight,
            child: Builder(
              builder: (context) {
                final button = ElevatedButton(
                  key: const Key('open'),
                  onPressed: () => result = showConvMorphSheet<String>(
                    context: context,
                    source: source,
                    builder: builder ?? sheet,
                  ),
                  child: const Text('Open'),
                );
                return mountSource
                    ? ConvMorphSource(
                        key: source,
                        color: Colors.deepPurple,
                        label: const Text('Open', key: labelCopy),
                        child: button,
                      )
                    : button;
              },
            ),
          ),
        ),
      ),
    );
  }

  bool sourceShown(WidgetTester tester) => tester
      .widget<Visibility>(
        find
            .ancestor(
              of: find.byKey(const Key('open')),
              matching: find.byType(Visibility),
            )
            .first,
      )
      .visible;

  testWidgets('the label copy fades out as the sheet forms', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pump();
    expect(find.byKey(labelCopy), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(labelCopy)),
      tester.getCenter(find.byKey(const Key('open'))),
    );

    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(labelCopy), findsNothing);
  });

  testWidgets('the label copy comes back at the end of a cancel',
      (tester) async {
    await pumpHost(tester);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(labelCopy), findsNothing);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(labelCopy), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(labelCopy), findsNothing);
    expect(sourceShown(tester), isTrue);
  });

  testWidgets('a cancel while still forming reverses without a jump',
      (tester) async {
    await pumpHost(tester);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final before = tester.getRect(bounds);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final after = tester.getRect(bounds);
    expect((after.width - before.width).abs(), lessThan(40));
    expect(after.width, lessThan(before.width));

    await tester.pumpAndSettle();
    expect(bounds, findsNothing);
    expect(sourceShown(tester), isTrue);
  });

  testWidgets('a drag is ignored until the sheet has formed', (tester) async {
    await pumpHost(tester);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final gesture = await tester.startGesture(tester.getCenter(bounds));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Submit'), findsOneWidget, reason: 'still open');
    expect(tester.getRect(bounds).bottom, 600);
  });

  testWidgets('a submit completes the future while the sheet slides down',
      (tester) async {
    await pumpHost(tester);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    final formed = tester.getRect(bounds);

    await tester.tap(find.text('Submit'));
    String? popped;
    result.then((value) => popped = value);
    await tester.pump();
    expect(popped, 'done');

    await tester.pump(const Duration(milliseconds: 100));
    final sliding = tester.getRect(bounds);
    expect(sliding.width, formed.width);
    expect(sliding.top, greaterThan(formed.top));
    expect(sourceShown(tester), isFalse);

    await tester.pumpAndSettle();
    expect(bounds, findsNothing);
    expect(sourceShown(tester), isTrue);
  });

  testWidgets('the scrim carries the modal sheet dismiss semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpHost(tester);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(const DefaultMaterialLocalizations().scrimLabel),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('sheet content can wait for the sheet to form', (tester) async {
    final seen = <Animation<double>?>[];
    await pumpHost(
      tester,
      builder: (context) {
        seen.add(convMorphSheetFormingOf(context));
        return sheet(context);
      },
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pump();
    expect(seen.first, isNotNull);
    expect(convMorphSheetFormingOf(sheetContext!), isNotNull);

    await tester.pumpAndSettle();
    expect(convMorphSheetFormingOf(sheetContext!), isNull);
    expect(
      convMorphSheetFormingOf(tester.element(find.byKey(const Key('open')))),
      isNull,
      reason: 'not inside a morph sheet',
    );
  });

  testWidgets('falls back to the plain sheet when the source is not mounted',
      (tester) async {
    await pumpHost(tester, mountSource: false);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(bounds, findsNothing);
    expect(convMorphSheetFormingOf(sheetContext!), isNull);
  });

  testWidgets('the source comes back if the route is removed outright',
      (tester) async {
    await pumpHost(tester);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(sourceShown(tester), isFalse);

    final route = ModalRoute.of(sheetContext!)!;
    Navigator.of(sheetContext!).removeRoute(route);
    await tester.pumpAndSettle();
    expect(bounds, findsNothing);
    expect(sourceShown(tester), isTrue);
  });
}
