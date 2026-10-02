import 'package:attendance_tracker/core/design/widgets/conv_widgets.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/presentation/add_guest_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Added = ({String name, bool isPresent, bool isGuest, Member? existing});

void main() {
  final jon = Member(id: 'jon', displayName: 'Jon Reyes');
  final jonah = Member(id: 'jonah', displayName: 'Jonah Abel');

  Future<List<_Added>> pumpSheet(
    WidgetTester tester, {
    Set<String>? rosterMemberIds,
  }) async {
    final added = <_Added>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => AddMemberSheet(
                  onAdd: (name, isPresent, isGuest, existing) => added.add((
                    name: name,
                    isPresent: isPresent,
                    isGuest: isGuest,
                    existing: existing,
                  )),
                  availableMembers: [jon, jonah],
                  families: [
                    Family(id: 'f-reyes', displayName: 'Reyes', members: [jon]),
                  ],
                  rosterMemberIds: rosterMemberIds,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return added;
  }

  testWidgets('opens as "Add someone" with both submit pills',
      (tester) async {
    await pumpSheet(tester);
    expect(find.text('Add someone'), findsOneWidget);
    expect(find.byKey(const Key('addSheetAddToRoster')), findsOneWidget);
    expect(find.byKey(const Key('addSheetMarkGuest')), findsOneWidget);
  });

  testWidgets('only the violet "Add to roster" pill presses in', (
    tester,
  ) async {
    await pumpSheet(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('addSheetAddToRoster')),
        matching: find.byType(ConvPressable),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('addSheetMarkGuest')),
        matching: find.byType(ConvPressable),
      ),
      findsNothing,
    );
  });

  testWidgets('submit pills do nothing until a name is typed', (tester) async {
    final added = await pumpSheet(tester);
    await tester.tap(find.byKey(const Key('addSheetAddToRoster')));
    await tester.tap(find.byKey(const Key('addSheetMarkGuest')));
    await tester.pumpAndSettle();

    expect(added, isEmpty);
    expect(find.text('Add someone'), findsOneWidget);
  });

  testWidgets('"Add to roster" adds a new present member and closes',
      (tester) async {
    final added = await pumpSheet(tester);
    await tester.enterText(find.byKey(const Key('addSheetNameField')), 'Ana Li');
    await tester.tap(find.byKey(const Key('addSheetAddToRoster')));
    await tester.pumpAndSettle();

    expect(added.single.name, 'Ana Li');
    expect(added.single.isPresent, isTrue);
    expect(added.single.isGuest, isFalse);
    expect(added.single.existing, isNull);
    expect(find.text('Add someone'), findsNothing);
  });

  testWidgets('"Mark as guest" adds a present guest and closes',
      (tester) async {
    final added = await pumpSheet(tester);
    await tester.enterText(find.byKey(const Key('addSheetNameField')), 'Ana Li');
    await tester.tap(find.byKey(const Key('addSheetMarkGuest')));
    await tester.pumpAndSettle();

    expect(added.single.isGuest, isTrue);
    expect(added.single.isPresent, isTrue);
    expect(find.text('Add someone'), findsNothing);
  });

  testWidgets('the keyboard action adds to the roster', (tester) async {
    final added = await pumpSheet(tester);
    await tester.enterText(find.byKey(const Key('addSheetNameField')), 'Ana Li');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(added.single.isGuest, isFalse);
  });

  testWidgets('tapping a suggested member marks them here in one tap',
      (tester) async {
    final added = await pumpSheet(tester);
    await tester.enterText(find.byKey(const Key('addSheetNameField')), 'jon');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addSheetSuggestion_jon')));
    await tester.pumpAndSettle();

    expect(added.single.existing, jon);
    expect(added.single.isPresent, isTrue);
    expect(find.text('Add someone'), findsNothing);
  });

  testWidgets('suggestions say whether the person is on this event',
      (tester) async {
    await pumpSheet(tester, rosterMemberIds: {'jonah'});
    await tester.enterText(find.byKey(const Key('addSheetNameField')), 'jon');
    await tester.pumpAndSettle();

    expect(find.text('Reyes · not on this event'), findsOneWidget);
    expect(find.text('Loner · on this event'), findsOneWidget);
  });
}
