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

  // The insights pages scroll; give tests a tall viewport so lazily-built
  // rows (ranked members, recent sessions, stat tiles) all lay out.
  void tallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

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
      tallSurface(tester);
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
      expect(find.text('RECENT SESSIONS'), findsOneWidget);
    });

    testWidgets('renders the average hero and range selector', (tester) async {
      tallSurface(tester);
      final members = [Member(id: 'm1', displayName: 'Alice Smith')];
      final sessions = List.generate(
        4,
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

      // All present → 100% average, with the range segmented control + tiles.
      expect(find.text('Avg · 4 sessions'.toUpperCase()), findsOneWidget);
      // "12 wk" appears in both the segmented control and the Average tile sub.
      expect(find.text('12 wk'), findsWidgets);
      expect(find.text('6 mo'), findsOneWidget);
      expect(find.text('Year'), findsOneWidget);
      expect(find.text('BEST'), findsOneWidget);
      expect(find.text('LOWEST'), findsOneWidget);
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
      expect(find.text('Smith family'), findsOneWidget);
      // Hero shows the "Most consistent" eyebrow and the "SESSIONS" ratio label.
      expect(find.text('MOST CONSISTENT'), findsOneWidget);
      expect(find.text('SESSIONS'), findsOneWidget);
    });

    testWidgets('ranks additional members below the hero', (tester) async {
      tallSurface(tester);
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
      // The hero member's family caption is shown.
      expect(find.text('Smith family'), findsOneWidget);
      // Ranked rows carry a hits/window ratio eyebrow (e.g. "8/8").
      expect(find.text('8/8'), findsWidgets);
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
  });
}
