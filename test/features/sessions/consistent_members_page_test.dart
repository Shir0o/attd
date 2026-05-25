import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/sessions/presentation/consistent_members_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConsistentMembersPage', () {
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

    testWidgets('renders empty state when no member meets threshold', (
      tester,
    ) async {
      final members = [Member(id: 'm1', displayName: 'Alice')];
      final sessions = List.generate(
        8,
        (i) => sessionWith(
          id: 's$i',
          date: DateTime(2026, 1, i + 1),
          statuses: {'m1': AttendanceStatus.absent},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ConsistentMembersPage(
            event: event,
            sessions: sessions,
            members: members,
            disableAnimations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No regulars yet'), findsOneWidget);
    });

    testWidgets('lists members at or above the threshold', (tester) async {
      final members = [
        Member(id: 'm1', displayName: 'Alice Smith'),
        Member(id: 'm2', displayName: 'Bob Smith'),
      ];
      final sessions = List.generate(
        8,
        (i) => sessionWith(
          id: 's$i',
          date: DateTime(2026, 1, i + 1),
          statuses: {
            'm1': AttendanceStatus.present,
            'm2': i < 6 ? AttendanceStatus.present : AttendanceStatus.absent,
          },
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ConsistentMembersPage(
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
      // Bob has 6/8 — below the >=7 threshold — should be excluded.
      expect(find.text('Bob Smith'), findsNothing);
    });
  });
}
