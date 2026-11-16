import 'package:attendance_tracker/core/design/app_colors.dart';
import 'package:attendance_tracker/core/design/app_shimmer.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/presentation/attendance_roster_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef ToggleCall = ({String id, bool present});

Session sessionWith({
  required List<Member> members,
  AttendanceStatus seedStatus = AttendanceStatus.absent,
}) {
  final now = DateTime(2025, 1, 1);
  return Session(
    id: 's',
    title: 'Test',
    sessionDate: now,
    createdAt: now,
    updatedAt: now,
    createdBy: 'User',
    records: [
      for (final m in members)
        SessionRecord(
          memberId: m.id,
          attendee: m.displayName,
          status: seedStatus,
          recordedAt: now,
          recordedBy: 'User',
        ),
    ],
  );
}

Future<void> pumpRoster(
  WidgetTester tester, {
  required Session session,
  required List<Family> families,
  required List<ToggleCall> toggleLog,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 800,
          child: AttendanceRosterList(
            session: session,
            families: families,
            disableAnimations: true,
            onToggle: (m, p) async {
              toggleLog.add((id: m.id, present: p));
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final alice = Member(id: 'a', displayName: 'Alice');
  final bob = Member(id: 'b', displayName: 'Bob');
  final carol = Member(id: 'c', displayName: 'Carol');
  final smiths = Family(
    id: 'smith',
    displayName: 'Smith Family',
    members: [alice, bob],
  );
  final jones = Family(
    id: 'jones',
    displayName: 'Jones Family',
    members: [carol],
  );

  testWidgets('search by member name shows only that member', (tester) async {
    final session = sessionWith(members: [alice, bob, carol]);
    final log = <ToggleCall>[];
    await pumpRoster(
      tester,
      session: session,
      families: [smiths, jones],
      toggleLog: log,
    );
    await tester.enterText(
      find.byKey(const Key('rosterSearchField')),
      'Alice',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('absent_row_a')), findsOneWidget);
    expect(find.byKey(const ValueKey('absent_row_b')), findsNothing);
    expect(find.byKey(const ValueKey('absent_row_c')), findsNothing);
  });

  testWidgets('is always grouped by status, with no grouping toggle',
      (tester) async {
    final now = DateTime(2025, 1, 1);
    SessionRecord rec(Member m, AttendanceStatus st) => SessionRecord(
          memberId: m.id,
          attendee: m.displayName,
          status: st,
          recordedAt: now,
          recordedBy: 'User',
        );
    final session = Session(
      id: 's',
      title: 't',
      sessionDate: now,
      createdAt: now,
      updatedAt: now,
      createdBy: 'User',
      records: [
        rec(alice, AttendanceStatus.present),
        rec(bob, AttendanceStatus.absent),
      ],
    );
    await pumpRoster(
      tester,
      session: session,
      families: [smiths],
      toggleLog: <ToggleCall>[],
    );
    expect(find.text('MARKED PRESENT'), findsOneWidget);
    expect(find.text('MARKED ABSENT'), findsOneWidget);
    // No family header, no By family / By status toggle, no bulk "All" pill.
    expect(find.text('Smith Family'), findsNothing);
    expect(find.text('By family'), findsNothing);
    expect(find.text('By status'), findsNothing);
    expect(find.byKey(const Key('rosterGroupingToggle')), findsNothing);
    expect(find.byKey(const Key('rosterMarkAllMenu')), findsNothing);
    expect(find.text('All'), findsNothing);
  });

  testWidgets(
    'member in two families renders once in status view',
    (tester) async {
      final aliceSolo = Family(
        id: 'alice-solo',
        displayName: 'Alice',
        members: [alice],
        isAutoSingleton: true,
      );
      final session = sessionWith(members: [alice, bob]);
      final log = <ToggleCall>[];
      await pumpRoster(
        tester,
        session: session,
        families: [smiths, aliceSolo],
        toggleLog: log,
      );
      expect(find.text('Alice'), findsOneWidget);
    },
  );

  testWidgets('rows carry no late affordance or late label', (tester) async {
    final now = DateTime(2025, 1, 1);
    final session = Session(
      id: 's',
      title: 't',
      sessionDate: now,
      createdAt: now,
      updatedAt: now,
      createdBy: 'User',
      records: [
        SessionRecord(
          memberId: alice.id,
          attendee: alice.displayName,
          status: AttendanceStatus.present,
          recordedAt: now,
          recordedBy: 'User',
          isLate: true,
        ),
      ],
    );
    await pumpRoster(
      tester,
      session: session,
      families: [smiths],
      toggleLog: <ToggleCall>[],
    );
    expect(find.byKey(const ValueKey('memberLate_a')), findsNothing);
    expect(find.byIcon(Icons.schedule_outlined), findsNothing);
    expect(find.text('Marked present'), findsOneWidget);
    expect(find.textContaining('late'), findsNothing);
  });

  group('per-row more actions', () {
    Future<void> pumpWithActions(
      WidgetTester tester, {
      required List<String> edited,
      required List<String> removed,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              child: AttendanceRosterList(
                session: sessionWith(members: [alice, bob]),
                families: [smiths],
                disableAnimations: true,
                onToggle: (m, p) async {},
                onEdit: (m) => edited.add(m.id),
                onRemove: (m) => removed.add(m.id),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final moreAlice = find.byTooltip('More actions for Alice');

    testWidgets('each row has a 48dp control labelled with the name',
        (tester) async {
      await pumpWithActions(tester, edited: [], removed: []);
      expect(moreAlice, findsOneWidget);
      expect(find.byTooltip('More actions for Bob'), findsOneWidget);
      final size = tester.getSize(moreAlice);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('Edit name calls onEdit for that member', (tester) async {
      final edited = <String>[];
      await pumpWithActions(tester, edited: edited, removed: []);
      await tester.tap(moreAlice);
      await tester.pumpAndSettle();
      expect(find.text('Edit name'), findsOneWidget);
      expect(find.text('Remove from session'), findsOneWidget);
      await tester.tap(find.text('Edit name'));
      await tester.pumpAndSettle();
      expect(edited, ['a']);
    });

    testWidgets('Remove from session calls onRemove, in danger ink',
        (tester) async {
      final removed = <String>[];
      await pumpWithActions(tester, edited: [], removed: removed);
      await tester.tap(moreAlice);
      await tester.pumpAndSettle();
      final remove = tester.widget<Text>(find.text('Remove from session'));
      expect(remove.style?.color, ConvocationColors.light.danger);
      await tester.tap(find.text('Remove from session'));
      await tester.pumpAndSettle();
      expect(removed, ['a']);
    });

    testWidgets('rows are not swipeable and no control without callbacks',
        (tester) async {
      await pumpWithActions(tester, edited: [], removed: []);
      expect(find.byType(Dismissible), findsNothing);

      await pumpRoster(
        tester,
        session: sessionWith(members: [alice]),
        families: [smiths],
        toggleLog: <ToggleCall>[],
      );
      expect(find.byTooltip('More actions for Alice'), findsNothing);
    });
  });

  testWidgets('the skeleton crossfades into the roster after 800 ms (#222 M7)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            child: AttendanceRosterList(
              session: sessionWith(members: [alice]),
              families: [
                Family(id: 'f', displayName: 'Solo', members: [alice]),
              ],
                      onToggle: (m, p) async {},
            ),
          ),
        ),
      ),
    );
    expect(find.byType(AppShimmer), findsWidgets);
    expect(find.text('Alice'), findsNothing);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AppShimmer), findsWidgets, reason: 'still fading out');
    expect(find.text('Alice'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(AppShimmer), findsNothing);
    expect(find.text('Alice'), findsOneWidget);
  });

  group('rows at large text', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets(
          'row with name, toggle and more control fits at ${scale}x',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AttendanceRosterList(
                session: sessionWith(members: [alice]),
                families: const [],
                disableAnimations: true,
                onToggle: (_, __) async {},
                onEdit: (_) {},
                onRemove: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Alice'), findsOneWidget);
        expect(find.byTooltip('More actions for Alice'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
