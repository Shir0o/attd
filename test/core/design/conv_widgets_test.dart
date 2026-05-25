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
}
