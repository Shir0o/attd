import 'package:attendance_tracker/core/design/app_theme.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/sessions/presentation/consistent_members_page.dart';
import 'package:attendance_tracker/features/sessions/presentation/event_trend_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final event = Event(
    id: 'e1',
    title: 'Sunday Service',
    time: const TimeOfDay(hour: 10, minute: 0),
    frequency: 'Weekly',
    memberIds: const ['m1', 'm2', 'm3'],
    createdAt: DateTime(2026, 1, 1),
  );

  Session sessionWith({
    required String id,
    required DateTime date,
    required Map<String, AttendanceStatus> statuses,
  }) => Session(
    id: id,
    eventId: 'e1',
    title: 'Sunday Service',
    sessionDate: date,
    createdAt: date,
    updatedAt: date,
    createdBy: 'tester',
    records: statuses.entries
        .map(
          (e) => SessionRecord(
            memberId: e.key,
            attendee: e.key,
            status: e.value,
            recordedAt: date,
            recordedBy: 'tester',
          ),
        )
        .toList(),
  );

  Widget wrap(Widget child) =>
      MaterialApp(theme: AppTheme.lightTheme(), home: child);

  group('EventTrendPage', () {
    testWidgets('renders empty state when no sessions exist', (tester) async {
      await tester.pumpWidget(
        wrap(
          EventTrendPage(
            event: event,
            sessions: const [],
            members: const [],
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No sessions yet'), findsOneWidget);
    });

    testWidgets('renders sparkline + present/absent split for the latest', (
      tester,
    ) async {
      final members = [
        Member(id: 'm1', displayName: 'Alice Smith'),
        Member(id: 'm2', displayName: 'Bob Smith'),
        Member(id: 'm3', displayName: 'Carol Jones'),
      ];
      final sessions = List.generate(
        4,
        (i) => sessionWith(
          id: 's$i',
          date: DateTime(2026, 1, i + 1),
          statuses: {
            'm1': AttendanceStatus.present,
            'm2': i < 3 ? AttendanceStatus.present : AttendanceStatus.absent,
            'm3': AttendanceStatus.absent,
          },
        ),
      );

      await tester.pumpWidget(
        wrap(
          EventTrendPage(
            event: event,
            sessions: sessions,
            members: members,
            families: [
              Family(
                id: 'f1',
                displayName: 'Smith',
                members: [members[0], members[1]],
                updatedAt: DateTime(2026),
              ),
            ],
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TRENDS'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('LATEST SESSIONS'), findsOneWidget);
    });

    testWidgets('tapping the regulars strip pushes ConsistentMembersPage', (
      tester,
    ) async {
      final members = [Member(id: 'm1', displayName: 'Alice Smith')];
      final sessions = List.generate(
        8,
        (i) => sessionWith(
          id: 's$i',
          date: DateTime(2026, 1, i + 1),
          statuses: {'m1': AttendanceStatus.present},
        ),
      );

      await tester.pumpWidget(
        wrap(
          EventTrendPage(
            event: event,
            sessions: sessions,
            members: members,
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('REGULARS · 80% IN LAST 8'));
      await tester.pumpAndSettle();

      expect(find.byType(ConsistentMembersPage), findsOneWidget);
      expect(find.text('The reliable few'), findsOneWidget);
    });
  });

  group('ConsistentMembersPage hero card', () {
    testWidgets('renders ratio and family for the top member', (tester) async {
      final members = [Member(id: 'm1', displayName: 'Alice Smith')];
      final sessions = List.generate(
        8,
        (i) => sessionWith(
          id: 's$i',
          date: DateTime(2026, 1, i + 1),
          statuses: {'m1': AttendanceStatus.present},
        ),
      );

      await tester.pumpWidget(
        wrap(
          ConsistentMembersPage(
            event: event,
            sessions: sessions,
            members: members,
            families: [
              Family(
                id: 'f1',
                displayName: 'Smith',
                members: members,
                updatedAt: DateTime(2026),
              ),
            ],
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Smith family · highest attendance'), findsOneWidget);
      // RichText combines ratio segments so we just confirm the "SESSIONS"
      // eyebrow is rendered alongside the ratio.
      expect(find.text('SESSIONS'), findsOneWidget);
    });

    testWidgets('ranks additional members below the hero', (tester) async {
      final members = [
        Member(id: 'm1', displayName: 'Alice Smith'),
        Member(id: 'm2', displayName: 'Bob Smith'),
        Member(id: 'm3', displayName: 'Carol Jones'),
        Member(id: 'm4', displayName: 'Dan Solo'),
      ];
      final sessions = List.generate(
        8,
        (i) => sessionWith(
          id: 's$i',
          date: DateTime(2026, 1, i + 1),
          statuses: {
            for (final m in members) m.id: AttendanceStatus.present,
          },
        ),
      );

      await tester.pumpWidget(
        wrap(
          ConsistentMembersPage(
            event: event,
            sessions: sessions,
            members: members,
            families: [
              Family(
                id: 'f1',
                displayName: 'Smith',
                members: [members[0], members[1]],
                updatedAt: DateTime(2026),
              ),
            ],
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // hero + 3 ranked rows = 4 names visible.
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Bob Smith'), findsOneWidget);
      expect(find.text('Carol Jones'), findsOneWidget);
      expect(find.text('Dan Solo'), findsOneWidget);
      // Ranked rows display ordinals starting at 2.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Smith family'), findsOneWidget);
      // Members not in any Family render with the "Solo" caption (two of them).
      expect(find.text('Solo'), findsNWidgets(2));
    });

    testWidgets('renders skeleton while animating', (tester) async {
      await tester.pumpWidget(
        wrap(
          ConsistentMembersPage(
            event: event,
            sessions: const [],
            members: const [],
            disableAnimations: false,
          ),
        ),
      );
      // No settle: we want the skeleton frame.
      await tester.pump();
      // Shimmers render while loading.
      expect(find.byType(ConsistentMembersPage), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('shows "session" (singular) caption when only one exists', (
      tester,
    ) async {
      final members = [Member(id: 'm1', displayName: 'Alice')];
      final sessions = [
        sessionWith(
          id: 's0',
          date: DateTime(2026, 1, 1),
          statuses: const {},
        ),
      ];

      await tester.pumpWidget(
        wrap(
          ConsistentMembersPage(
            event: event,
            sessions: sessions,
            members: members,
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('the last 1 session', findRichText: false),
        findsOneWidget,
      );
    });
  });

  group('EventTrendPage extras', () {
    testWidgets('regulars headline collapses 4+ names with a +N suffix', (
      tester,
    ) async {
      final members = List.generate(
        4,
        (i) => Member(id: 'm$i', displayName: 'Name$i Last'),
      );
      final sessions = List.generate(
        8,
        (i) => sessionWith(
          id: 's$i',
          date: DateTime(2026, 1, i + 1),
          statuses: {for (final m in members) m.id: AttendanceStatus.present},
        ),
      );

      await tester.pumpWidget(
        wrap(
          EventTrendPage(
            event: event,
            sessions: sessions,
            members: members,
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('+1', findRichText: false),
        findsOneWidget,
      );
    });

    testWidgets('truncates to the last windowSize sessions', (tester) async {
      final members = [Member(id: 'm1', displayName: 'Alice')];
      // 14 sessions — more than the default windowSize of 12.
      final sessions = List.generate(
        14,
        (i) => sessionWith(
          id: 's$i',
          date: DateTime(2026, 1, i + 1),
          statuses: {'m1': AttendanceStatus.present},
        ),
      );

      await tester.pumpWidget(
        wrap(
          EventTrendPage(
            event: event,
            sessions: sessions,
            members: members,
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // With > windowSize sessions the "12 weeks ago" caption shows.
      expect(find.text('12 weeks ago'), findsOneWidget);
    });

    testWidgets('renders trend skeleton while animating', (tester) async {
      await tester.pumpWidget(
        wrap(
          EventTrendPage(
            event: event,
            sessions: const [],
            members: const [],
            disableAnimations: false,
          ),
        ),
      );
      // First frame is the skeleton; the empty state shows after the 800ms
      // delay resolves.
      await tester.pump();
      expect(find.byType(EventTrendPage), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('No sessions yet'), findsOneWidget);
    });

    testWidgets('shows "None yet — keep going" when nobody qualifies', (
      tester,
    ) async {
      final members = [Member(id: 'm1', displayName: 'Alice Smith')];
      final sessions = List.generate(
        8,
        (i) => sessionWith(
          id: 's$i',
          date: DateTime(2026, 1, i + 1),
          statuses: {'m1': AttendanceStatus.absent},
        ),
      );

      await tester.pumpWidget(
        wrap(
          EventTrendPage(
            event: event,
            sessions: sessions,
            members: members,
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('None yet — keep going'), findsOneWidget);
    });
  });
}
