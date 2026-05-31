import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/presentation/attendance_roster_list.dart';
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
            disableAnimations: true,
            onToggle: (m, p) async {
              toggleLog.add((id: m.id, present: p));
            },
            onFamilyToggle: familyLog == null
                ? null
                : (f, p) async =>
                    familyLog.add((familyId: f.id, present: p)),
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
    'mark-all sheet "All present" tile invokes onMarkAll with true',
    (tester) async {
      final session = sessionWith(members: [alice, bob, carol]);
      final log = <ToggleCall>[];
      final markedAll = <bool>[];
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
                onMarkAll: (present) async => markedAll.add(present),
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
      expect(markedAll, [true]);
    },
  );

  testWidgets('mark-all sheet cancel does not invoke the callback',
      (tester) async {
    final session = sessionWith(members: [alice, bob, carol]);
    final log = <ToggleCall>[];
    final markedAll = <bool>[];
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
              onMarkAll: (present) async => markedAll.add(present),
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
}
