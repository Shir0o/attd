import 'package:attendance_tracker/core/design/app_shimmer.dart';
import 'package:attendance_tracker/core/design/widgets/conv_widgets.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/presentation/attendance_roster_list.dart';
import 'package:attendance_tracker/features/attendance/presentation/mark_everyone_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef ToggleCall = ({String id, bool present});
typedef FamilyToggleCall = ({String familyId, bool present});

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
  List<FamilyToggleCall>? familyLog,
  RosterGrouping grouping = RosterGrouping.byFamily,
  Future<void> Function(Member member)? onToggleLate,
  bool showGroupingToggle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 800,
          child: AttendanceRosterList(
            session: session,
            families: families,
            initialGrouping: grouping,
            showGroupingToggle: showGroupingToggle,
            disableAnimations: true,
            onToggle: (m, p) async {
              toggleLog.add((id: m.id, present: p));
            },
            onFamilyToggle: familyLog == null
                ? null
                : (f, p) async =>
                    familyLog.add((familyId: f.id, present: p)),
            onToggleLate: onToggleLate,
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

  testWidgets('renders families with names and present counts', (tester) async {
    final session = sessionWith(members: [alice, bob, carol]);
    final log = <ToggleCall>[];
    await pumpRoster(
      tester,
      session: session,
      families: [smiths, jones],
      toggleLog: log,
    );
    expect(find.text('Smith Family'), findsOneWidget);
    expect(find.text('Jones Family'), findsOneWidget);
    expect(find.text('0 of 2 present'), findsOneWidget);
    expect(find.text('0 of 1 present'), findsOneWidget);
  });

  testWidgets('family "all present" button calls onFamilyToggle', (tester) async {
    final session = sessionWith(members: [alice, bob, carol]);
    final log = <ToggleCall>[];
    final familyLog = <FamilyToggleCall>[];
    await pumpRoster(
      tester,
      session: session,
      families: [smiths, jones],
      toggleLog: log,
      familyLog: familyLog,
    );
    await tester.tap(find.byKey(const ValueKey('familyAllPresent_smith')));
    await tester.pumpAndSettle();
    expect(familyLog, hasLength(1));
    expect(familyLog.single.familyId, 'smith');
    expect(familyLog.single.present, isTrue);
  });

  testWidgets(
      'family "all present" fans out to onToggle when onFamilyToggle absent',
      (tester) async {
    final session = sessionWith(members: [alice, bob, carol]);
    final log = <ToggleCall>[];
    await pumpRoster(
      tester,
      session: session,
      families: [smiths, jones],
      toggleLog: log,
    );
    await tester.tap(find.byKey(const ValueKey('familyAllPresent_smith')));
    await tester.pumpAndSettle();
    expect(log.map((e) => e.id).toList(), ['a', 'b']);
    expect(log.every((e) => e.present), isTrue);
  });

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
    expect(find.byKey(const ValueKey('member_row_smith_a')), findsOneWidget);
    expect(find.byKey(const ValueKey('member_row_smith_b')), findsNothing);
    expect(find.byKey(const ValueKey('member_row_jones_c')), findsNothing);
    // Smith family header still shown (alice belongs to it).
    expect(find.text('Smith Family'), findsOneWidget);
    expect(find.text('Jones Family'), findsNothing);
  });

  testWidgets('search by family name keeps all members in that family',
      (tester) async {
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
      'Smith',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('member_row_smith_a')), findsOneWidget);
    expect(find.byKey(const ValueKey('member_row_smith_b')), findsOneWidget);
    expect(find.byKey(const ValueKey('member_row_jones_c')), findsNothing);
  });

  testWidgets('grouping toggle switches between family and status views',
      (tester) async {
    final present = SessionRecord(
      memberId: alice.id,
      attendee: alice.displayName,
      status: AttendanceStatus.present,
      recordedAt: DateTime(2025, 1, 1),
      recordedBy: 'User',
    );
    final absent = SessionRecord(
      memberId: bob.id,
      attendee: bob.displayName,
      status: AttendanceStatus.absent,
      recordedAt: DateTime(2025, 1, 1),
      recordedBy: 'User',
    );
    final session = Session(
      id: 's',
      title: 't',
      sessionDate: DateTime(2025, 1, 1),
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      createdBy: 'User',
      records: [present, absent],
    );

    final log = <ToggleCall>[];
    await pumpRoster(
      tester,
      session: session,
      families: [smiths],
      toggleLog: log,
    );
    expect(find.text('Smith Family'), findsOneWidget);

    // Switch to "By status".
    await tester.tap(find.text('By status'));
    await tester.pumpAndSettle();

    expect(find.text('Smith Family'), findsNothing);
    expect(find.text('MARKED PRESENT'), findsOneWidget);
    expect(find.text('MARKED ABSENT'), findsOneWidget);
  });

  testWidgets(
    'auto-singleton families render as flat rows without a header',
    (tester) async {
      final dan = Member(id: 'd', displayName: 'Dan Solo');
      final eve = Member(id: 'e', displayName: 'Eve Lonely');
      final danFam = Family(
        id: 'dan-fam',
        displayName: 'Dan Solo',
        members: [dan],
        isAutoSingleton: true,
      );
      final eveFam = Family(
        id: 'eve-fam',
        displayName: 'Eve Lonely',
        members: [eve],
        isAutoSingleton: true,
      );
      final session = sessionWith(members: [alice, bob, dan, eve]);
      final log = <ToggleCall>[];
      await pumpRoster(
        tester,
        session: session,
        families: [smiths, danFam, eveFam],
        toggleLog: log,
      );
      // The real Smith family still gets a header.
      expect(find.text('Smith Family'), findsOneWidget);
      // Singletons do NOT get a per-family header — neither their name as a
      // header (which would be the bug) nor a "0 of 1 present" count.
      expect(find.text('Dan Solo'), findsOneWidget); // one row only
      expect(find.text('0 of 1 present'), findsNothing);
      // The shared "Members" section header is rendered above singletons.
      expect(find.text('MEMBERS'), findsOneWidget);
    },
  );

  testWidgets(
    'member in two families renders once in family view',
    (tester) async {
      // Alice belongs to both her real family and an auto-singleton — a known
      // data hazard. She must render only once (under the first family).
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
        grouping: RosterGrouping.byFamily,
      );
      expect(find.text('Alice'), findsOneWidget);
      expect(find.byKey(const ValueKey('member_row_smith_a')), findsOneWidget);
      expect(find.byKey(const ValueKey('singleton_row_a')), findsNothing);
    },
  );

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
        grouping: RosterGrouping.byStatus,
      );
      expect(find.text('Alice'), findsOneWidget);
    },
  );

  testWidgets(
    'mark-all sheet "All present" tile invokes onMarkAll with present',
    (tester) async {
      final session = sessionWith(members: [alice, bob, carol]);
      final log = <ToggleCall>[];
      final markedAll = <BulkMarkChoice>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              child: AttendanceRosterList(
                session: session,
                families: [smiths, jones],
                disableAnimations: true,
                onToggle: (m, p) async {
                  log.add((id: m.id, present: p));
                },
                onMarkAll: (choice) async => markedAll.add(choice),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rosterMarkAllMenu')));
      await tester.pumpAndSettle();
      // Sheet is up.
      expect(find.text('Bulk attendance'), findsOneWidget);
      await tester.tap(find.byKey(const Key('markEveryonePresent')));
      await tester.pumpAndSettle();
      expect(markedAll, [BulkMarkChoice.present]);
    },
  );

  testWidgets(
    'mark-all sheet "Smart defaults" tile invokes onMarkAll with smart',
    (tester) async {
      final session = sessionWith(members: [alice, bob, carol]);
      final markedAll = <BulkMarkChoice>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              child: AttendanceRosterList(
                session: session,
                families: [smiths, jones],
                disableAnimations: true,
                onToggle: (m, p) async {},
                onMarkAll: (choice) async => markedAll.add(choice),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rosterMarkAllMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('markEveryoneSmart')));
      await tester.pumpAndSettle();
      expect(markedAll, [BulkMarkChoice.smart]);
    },
  );

  testWidgets('mark-all sheet cancel does not invoke the callback',
      (tester) async {
    final session = sessionWith(members: [alice, bob, carol]);
    final log = <ToggleCall>[];
    final markedAll = <BulkMarkChoice>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            child: AttendanceRosterList(
              session: session,
              families: [smiths, jones],
              disableAnimations: true,
              onToggle: (m, p) async {
                log.add((id: m.id, present: p));
              },
              onMarkAll: (choice) async => markedAll.add(choice),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rosterMarkAllMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('markEveryoneCancel')));
    await tester.pumpAndSettle();
    expect(markedAll, isEmpty);
  });
  testWidgets('late affordance hidden when onToggleLate not supplied',
      (tester) async {
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
        ),
      ],
    );
    final log = <ToggleCall>[];
    await pumpRoster(
      tester,
      session: session,
      families: [smiths],
      toggleLog: log,
    );
    // No late affordance when the callback is absent — this omission is what
    // keeps the deck and fast-marking surfaces out of scope.
    expect(
      find.byKey(const ValueKey('memberLate_a')),
      findsNothing,
    );
  });

  testWidgets('late affordance renders only on present rows when enabled',
      (tester) async {
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
        ),
        SessionRecord(
          memberId: bob.id,
          attendee: bob.displayName,
          status: AttendanceStatus.absent,
          recordedAt: now,
          recordedBy: 'User',
        ),
      ],
    );
    final lateToggles = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            child: AttendanceRosterList(
              session: session,
              families: [smiths],
              disableAnimations: true,
              onToggle: (m, p) async {},
              onToggleLate: (m) async => lateToggles.add(m.id),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Present row: affordance exists. Absent row renders no affordance.
    expect(find.byKey(const ValueKey('memberLate_a')), findsOneWidget);
    expect(find.byKey(const ValueKey('memberLate_b')), findsNothing);

    // Tapping it flags the member late.
    await tester.tap(find.byKey(const ValueKey('memberLate_a')));
    await tester.pumpAndSettle();
    expect(lateToggles, ['a']);
  });

  testWidgets('late row subtitle says late', (tester) async {
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
      onToggleLate: (m) async {},
    );
    // The word "late" rides the row subtitle, so meaning is never only an
    // icon.
    expect(find.text('Marked present · late'), findsOneWidget);
  });

  group('Confirm CTA press feedback', () {
    Future<void> pumpConfirm(
      WidgetTester tester, {
      bool disableAnimations = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 800,
              child: AttendanceRosterList(
                session: sessionWith(
                  members: [alice, bob],
                  seedStatus: AttendanceStatus.present,
                ),
                families: [smiths],
                initialGrouping: RosterGrouping.byFamily,
                confirmMode: true,
                onConfirm: () {},
                disableAnimations: disableAnimations,
                onToggle: (m, p) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder scaleTransform() => find.descendant(
      of: find.byType(ConvPressable),
      matching: find.byType(Transform),
    );

    testWidgets('presses in while held when motion is on', (tester) async {
      await pumpConfirm(tester);
      final cta = find.byKey(const Key('rosterConfirmButton'));
      final gesture = await tester.startGesture(tester.getCenter(cta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(
        tester.widget<Transform>(scaleTransform().first).transform.entry(0, 0),
        closeTo(0.97, 0.001),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('separates from the list by tone, not a border', (tester) async {
      await pumpConfirm(tester);
      final bar = tester.widget<Container>(
        find.byKey(const Key('rosterConfirmBar')),
      );
      final decoration = bar.decoration! as BoxDecoration;
      expect(decoration.border, isNull);
      final c = tester.element(find.byKey(const Key('rosterConfirmBar'))).conv;
      expect(decoration.color, c.bg2);
    });

    testWidgets('does not scale when motion is disabled', (tester) async {
      await pumpConfirm(tester, disableAnimations: true);
      expect(find.byType(ConvPressable), findsOneWidget);
      expect(scaleTransform(), findsNothing);
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
              initialGrouping: RosterGrouping.byFamily,
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

  group('visitors label at large text', () {
    for (final scale in [1.3, 2.0]) {
      testWidgets('lays out without overflow at ${scale}x on a phone',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await pumpRoster(
          tester,
          session: sessionWith(members: [alice]),
          families: const [],
          toggleLog: <ToggleCall>[],
          // The grouping row overflows on its own at large text; keep it out
          // so this asserts only the visitors label.
          showGroupingToggle: false,
        );
        expect(find.text('VISITORS / OTHERS'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('grouping row at large text', () {
    final pill = find.byKey(const Key('rosterMarkAllPresent'));
    final label = find.text('Grouped by family');

    Future<List<BulkMarkChoice>> pumpPreset(
      WidgetTester tester,
      double scale, {
      double width = 390,
    }) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final marked = <BulkMarkChoice>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceRosterList(
              session: sessionWith(members: [alice, bob]),
              families: [smiths],
              showGroupingToggle: false,
              showGroupingPreset: true,
              showSearch: false,
              disableAnimations: true,
              onToggle: (_, __) async {},
              onMarkAll: (choice) async => marked.add(choice),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return marked;
    }

    testWidgets('label and All present share one line when they fit',
        (tester) async {
      // The test font is wider than the app's, so give it a wider screen.
      await pumpPreset(tester, 1.0, width: 600);
      expect(tester.takeException(), isNull);
      expect(
        tester.getCenter(pill).dy,
        closeTo(tester.getCenter(label).dy, 1),
      );
      expect(tester.getRect(pill).right, closeTo(600 - 16, 0.5));
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('All present drops below the label at ${scale}x text',
          (tester) async {
        final marked = await pumpPreset(tester, scale);
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(pill).top,
          greaterThanOrEqualTo(tester.getRect(label).bottom),
        );
        expect(tester.getRect(pill).right, lessThanOrEqualTo(390 - 16));
        expect(tester.getRect(label).right, lessThanOrEqualTo(390 - 16));
        await tester.tap(pill);
        expect(marked, [BulkMarkChoice.present]);
      });
    }
  });
}
