import 'package:attendance_tracker/core/design/app_motion.dart';
import 'package:attendance_tracker/core/design/app_shadows.dart';
import 'package:attendance_tracker/core/design/app_theme.dart';
import 'package:attendance_tracker/core/design/widgets/conv_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) =>
      MaterialApp(theme: AppTheme.lightTheme(), home: Scaffold(body: child));

  testWidgets('ConvAvatar renders the supplied letter', (tester) async {
    await tester.pumpWidget(wrap(const ConvAvatar(letter: 'A')));
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('ConvAvatar applies present tone', (tester) async {
    await tester.pumpWidget(
      wrap(const ConvAvatar(letter: 'P', tone: ConvTone.present)),
    );
    expect(find.text('P'), findsOneWidget);
  });

  testWidgets('ConvAvatar applies absent tone', (tester) async {
    await tester.pumpWidget(
      wrap(const ConvAvatar(letter: 'X', tone: ConvTone.absent)),
    );
    expect(find.text('X'), findsOneWidget);
  });

  testWidgets('ConvPill on + off variants tap callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        Column(
          children: [
            ConvPill(
              label: 'Tap me',
              isOn: true,
              onTap: () => taps++,
              leading: const Icon(Icons.add, size: 14),
            ),
            const ConvPill(label: 'Ghost', ghost: true),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Tap me'));
    expect(taps, 1);
    expect(find.text('Ghost'), findsOneWidget);
  });

  testWidgets('ConvStamp renders rotated label', (tester) async {
    await tester.pumpWidget(
      wrap(
        const Column(
          children: [
            ConvStamp(label: 'Present', tone: ConvTone.present),
            ConvStamp(label: 'Absent', tone: ConvTone.absent),
          ],
        ),
      ),
    );
    expect(find.text('PRESENT'), findsOneWidget);
    expect(find.text('ABSENT'), findsOneWidget);
  });

  testWidgets('ConvDayChip taps fire callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        ConvDayChip(
          day: 'M',
          active: true,
          onTap: () => taps++,
        ),
      ),
    );
    await tester.tap(find.text('M'));
    expect(taps, 1);
  });

  testWidgets('ConvToggle flips on tap', (tester) async {
    var value = false;
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) => ConvToggle(
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ConvToggle));
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });

  testWidgets('ConvStatChip renders label + value for each tone', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const Row(
          children: [
            Expanded(
              child: ConvStatChip(
                label: 'Present',
                value: '3',
                tone: ConvTone.present,
              ),
            ),
            Expanded(
              child: ConvStatChip(
                label: 'Absent',
                value: '2',
                tone: ConvTone.absent,
              ),
            ),
            Expanded(
              child: ConvStatChip(
                label: 'Total',
                value: '5',
                tone: ConvTone.neutral,
              ),
            ),
          ],
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('PRESENT'), findsOneWidget);
  });

  testWidgets('ConvSectionLabel renders for each tone', (tester) async {
    await tester.pumpWidget(
      wrap(
        const Column(
          children: [
            ConvSectionLabel(label: 'Hello', tone: ConvTone.present),
            ConvSectionLabel(label: 'Bye', tone: ConvTone.absent),
            ConvSectionLabel(label: 'Other'),
          ],
        ),
      ),
    );
    expect(find.text('HELLO'), findsOneWidget);
    expect(find.text('BYE'), findsOneWidget);
    expect(find.text('OTHER'), findsOneWidget);
  });

  testWidgets('ConvCard onTap registers taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        ConvCard(
          onTap: () => taps++,
          child: const Text('tap-card'),
        ),
      ),
    );
    await tester.tap(find.text('tap-card'));
    expect(taps, 1);
  });

  testWidgets('ConvCardSoft onTap registers taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        ConvCardSoft(
          onTap: () => taps++,
          child: const Text('tap-soft'),
        ),
      ),
    );
    await tester.tap(find.text('tap-soft'));
    expect(taps, 1);
  });

  testWidgets('ConvFab invokes onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        ConvFab(
          onPressed: () => taps++,
          tooltip: 'add',
        ),
      ),
    );
    await tester.tap(find.byType(ConvFab));
    expect(taps, 1);
  });

  testWidgets('ConvIconButton invokes onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        ConvIconButton(icon: Icons.search, onPressed: () => taps++),
      ),
    );
    await tester.tap(find.byIcon(Icons.search));
    expect(taps, 1);
  });

  testWidgets('ConvSegmented changes selection on tap', (tester) async {
    var index = 0;
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) => ConvSegmented(
            options: const [
              ConvSegmentOption(label: 'Family', icon: Icons.family_restroom),
              ConvSegmentOption(label: 'Status', icon: Icons.check),
            ],
            selectedIndex: index,
            onChanged: (i) => setState(() => index = i),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Status'));
    await tester.pump();
    expect(index, 1);
  });

  testWidgets('ConvEyebrow uppercases supplied text', (tester) async {
    await tester.pumpWidget(wrap(const ConvEyebrow('regulars')));
    expect(find.text('REGULARS'), findsOneWidget);
  });

  group('motionEnabled', () {
    Future<bool> read(
      WidgetTester tester, {
      required bool flag,
      required bool system,
    }) async {
      late bool result;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: system),
          child: Builder(
            builder: (context) {
              result = motionEnabled(context, disableAnimations: flag);
              return const SizedBox();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('is on only when neither the flag nor the system disables it', (
      tester,
    ) async {
      expect(await read(tester, flag: false, system: false), isTrue);
      expect(await read(tester, flag: true, system: false), isFalse);
      expect(await read(tester, flag: false, system: true), isFalse);
      expect(await read(tester, flag: true, system: true), isFalse);
    });

    testWidgets('defaults the flag to off', (tester) async {
      late bool result;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            result = motionEnabled(context);
            return const SizedBox();
          },
        ),
      );
      expect(result, isTrue);
    });
  });

  group('ConvPressable', () {
    double? scaleOf(WidgetTester tester) {
      final transforms = find.descendant(
        of: find.byType(ConvPressable),
        matching: find.byType(Transform),
      );
      if (transforms.evaluate().isEmpty) return null;
      return tester
          .widget<Transform>(transforms.first)
          .transform
          .entry(0, 0);
    }

    Widget pressable({
      required VoidCallback onTap,
      ConvPressPreset preset = ConvPressPreset.pressIn,
      bool disableAnimations = false,
      bool systemDisable = false,
    }) => MediaQuery(
      data: MediaQueryData(disableAnimations: systemDisable),
      child: wrap(
        Center(
          child: ConvPressable(
            preset: preset,
            disableAnimations: disableAnimations,
            child: Material(
              child: InkWell(
                key: const Key('target'),
                onTap: onTap,
                child: const SizedBox(width: 120, height: 48),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('pressIn dips to 0.97 while held and returns to 1', (
      tester,
    ) async {
      await tester.pumpWidget(pressable(onTap: () {}));
      expect(scaleOf(tester), 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('target'))),
      );
      await tester.pump(); // starts the ticker
      await tester.pump(const Duration(milliseconds: 110));
      expect(scaleOf(tester), closeTo(0.97, 0.001));

      await gesture.up();
      await tester.pump(); // starts the ticker
      await tester.pump(const Duration(milliseconds: 260));
      expect(scaleOf(tester), closeTo(1, 0.0001));
    });

    testWidgets('pop dips to 0.94 while held and springs back to 1', (
      tester,
    ) async {
      await tester.pumpWidget(
        pressable(onTap: () {}, preset: ConvPressPreset.pop),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('target'))),
      );
      await tester.pump(); // starts the ticker
      await tester.pump(const Duration(milliseconds: 110));
      expect(scaleOf(tester), closeTo(0.94, 0.001));

      await gesture.up();
      await tester.pump(); // starts the ticker
      await tester.pump(const Duration(milliseconds: 320));
      expect(scaleOf(tester), closeTo(1, 0.0001));
    });

    testWidgets('a cancelled press also springs back', (tester) async {
      await tester.pumpWidget(pressable(onTap: () {}));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('target'))),
      );
      await tester.pump(); // starts the ticker
      await tester.pump(const Duration(milliseconds: 110));
      await gesture.cancel();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));
      expect(scaleOf(tester), closeTo(1, 0.0001));
    });

    testWidgets('does not swallow taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(pressable(onTap: () => taps++));
      await tester.tap(find.byKey(const Key('target')));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    for (final (name, flag, system) in [
      ('the test flag', true, false),
      ('the system setting', false, true),
    ]) {
      testWidgets('is a no-op when $name disables motion', (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          pressable(
            onTap: () => taps++,
            disableAnimations: flag,
            systemDisable: system,
          ),
        );
        expect(scaleOf(tester), isNull);
        await tester.tap(find.byKey(const Key('target')));
        await tester.pumpAndSettle();
        expect(taps, 1);
      });
    }

    testWidgets('builder reports how far the control is pressed in', (
      tester,
    ) async {
      final seen = <double>[];
      await tester.pumpWidget(
        wrap(
          Center(
            child: ConvPressable.builder(
              builder: (context, pressed) {
                seen.add(pressed);
                return const SizedBox(
                  key: Key('target'),
                  width: 100,
                  height: 40,
                  child: ColoredBox(color: Colors.purple),
                );
              },
            ),
          ),
        ),
      );
      expect(seen.last, 0);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('target'))),
      );
      await tester.pump(); // starts the ticker
      await tester.pump(const Duration(milliseconds: 110));
      expect(seen.last, closeTo(1, 0.01));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(seen.last, closeTo(0, 0.001));
    });

    testWidgets('builder gets 0 and no transform when motion is off', (
      tester,
    ) async {
      double? pressed;
      await tester.pumpWidget(
        wrap(
          ConvPressable.builder(
            disableAnimations: true,
            builder: (context, p) {
              pressed = p;
              return const SizedBox(width: 10, height: 10);
            },
          ),
        ),
      );
      expect(pressed, 0);
      expect(scaleOf(tester), isNull);
    });

    testWidgets('ConvFab presses in and still fires onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(ConvFab(onPressed: () => taps++)));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ConvFab)),
      );
      await tester.pump(); // starts the ticker
      await tester.pump(const Duration(milliseconds: 110));
      expect(scaleOf(tester), closeTo(0.97, 0.001));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(scaleOf(tester), closeTo(1, 0.0001));
    });
  });

  test('AppShadows.fab tightens as it is pressed', () {
    final rest = AppShadows.fab(Colors.purple).single;
    final pressed = AppShadows.fab(Colors.purple, pressed: 1).single;
    expect(pressed.blurRadius, lessThan(rest.blurRadius));
    expect(pressed.offset.dy, lessThan(rest.offset.dy));
  });

  group('FAB to pill shuttle', () {
    Widget shuttleAt(double t) {
      final builder = convFabPillShuttleBuilder(
        label: 'Create event',
        color: Colors.purple,
        onColor: Colors.white,
        labelStyle: const TextStyle(fontSize: 16),
      );
      return Builder(
        builder: (context) => builder(
          context,
          AlwaysStoppedAnimation<double>(t),
          HeroFlightDirection.push,
          context,
          context,
        ),
      );
    }

    double opacityOf(WidgetTester tester, Finder f) => tester
        .widget<Opacity>(
          find.ancestor(of: f, matching: find.byType(Opacity)).first,
        )
        .opacity;

    testWidgets('starts as the + FAB and ends as the label pill', (
      tester,
    ) async {
      final label = find.byKey(const ValueKey('fab_pill_shuttle_label'));
      await tester.pumpWidget(
        wrap(Center(child: SizedBox(width: 56, height: 56, child: shuttleAt(0)))),
      );
      expect(opacityOf(tester, find.byIcon(Icons.add)), 1);
      expect(opacityOf(tester, label), 0);

      await tester.pumpWidget(
        wrap(
          Center(child: SizedBox(width: 300, height: 56, child: shuttleAt(1))),
        ),
      );
      expect(opacityOf(tester, find.byIcon(Icons.add)), 0);
      expect(opacityOf(tester, label), 1);
    });

    testWidgets('crossfades: icon gone by ~35%, label not before ~45%', (
      tester,
    ) async {
      final label = find.byKey(const ValueKey('fab_pill_shuttle_label'));
      await tester.pumpWidget(
        wrap(Center(child: SizedBox(width: 120, height: 56, child: shuttleAt(0.4)))),
      );
      expect(opacityOf(tester, find.byIcon(Icons.add)), 0);
      expect(opacityOf(tester, label), 0);
    });

    testWidgets('keeps the label on one line even in a narrow box', (
      tester,
    ) async {
      final label = find.byKey(const ValueKey('fab_pill_shuttle_label'));
      await tester.pumpWidget(
        wrap(Center(child: SizedBox(width: 56, height: 56, child: shuttleAt(0.6)))),
      );
      final text = tester.widget<Text>(label);
      expect(text.softWrap, isFalse);
      expect(text.maxLines, 1);
      // Laid out at its intrinsic width, wider than the 56 px box, one line.
      expect(tester.getSize(label).width, greaterThan(56));
      expect(tester.getSize(label).height, lessThan(30));
    });

    test('convArcRectTween is a Material arc tween', () {
      final tween = convArcRectTween(
        const Rect.fromLTWH(0, 0, 10, 10),
        const Rect.fromLTWH(100, 100, 50, 10),
      );
      expect(tween, isA<MaterialRectArcTween>());
    });
  });
}
