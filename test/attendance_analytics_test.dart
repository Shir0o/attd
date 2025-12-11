import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/analytics/attendance_analytics.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Session buildSession({
    required String id,
    required String title,
    required DateTime date,
    required List<SessionRecord> records,
  }) {
    return Session(
      id: id,
      title: title,
      sessionDate: date,
      records: records,
      createdAt: date,
      updatedAt: date,
      createdBy: 'Tester',
    );
  }

  SessionRecord record(String attendee, AttendanceStatus status, DateTime when) {
    return SessionRecord(
      attendee: attendee,
      status: status,
      recordedAt: when,
      recordedBy: 'Tester',
    );
  }

  final families = [
    Family(
      id: 'fam-1',
      displayName: 'Rivera',
      members: const [
        Member(id: 'm1', displayName: 'Alana Rivera'),
        Member(id: 'm2', displayName: 'Mateo Rivera'),
      ],
    ),
    Family(
      id: 'fam-2',
      displayName: 'Patel',
      members: const [Member(id: 'm3', displayName: 'Priya Patel')],
    ),
  ];

  test('calculates streaks and watchlist flags within window', () {
    final now = DateTime(2024, 1, 10);
    final sessions = [
      buildSession(
        id: 's1',
        title: 'Check-in',
        date: DateTime(2024, 1, 10),
        records: [
          record('Alana Rivera', AttendanceStatus.absent, now),
          record('Mateo Rivera', AttendanceStatus.present, now),
        ],
      ),
      buildSession(
        id: 's2',
        title: 'Check-in',
        date: DateTime(2024, 1, 8),
        records: [
          record('Alana Rivera', AttendanceStatus.absent, now),
          record('Mateo Rivera', AttendanceStatus.present, now),
          record('Priya Patel', AttendanceStatus.present, now),
        ],
      ),
      buildSession(
        id: 's3',
        title: 'Earlier',
        date: DateTime(2023, 12, 20),
        records: [record('Priya Patel', AttendanceStatus.absent, now)],
      ),
    ];

    final analytics = calculateAttendanceAnalytics(
      sessions: sessions,
      families: families,
      range: AnalyticsRange.last7Days.resolve(now),
    );

    expect(analytics.breakdown.present, 3);
    expect(analytics.breakdown.absent, 2);
    expect(analytics.attendees['Alana Rivera']!.absenceStreak, 2);
    expect(analytics.trend.length, 2);
    expect(
      analytics.watchlist.map((flag) => flag.subject),
      contains('Alana Rivera'),
    );
  });

  test('aggregates families and applies watchlist thresholds', () {
    final now = DateTime(2024, 2, 1);
    final sessions = [
      buildSession(
        id: 's1',
        title: 'Session',
        date: DateTime(2024, 1, 31),
        records: [
          record('Priya Patel', AttendanceStatus.absent, now),
          record('Mateo Rivera', AttendanceStatus.present, now),
        ],
      ),
      buildSession(
        id: 's2',
        title: 'Session',
        date: DateTime(2024, 1, 29),
        records: [
          record('Priya Patel', AttendanceStatus.absent, now),
          record('Mateo Rivera', AttendanceStatus.present, now),
        ],
      ),
      buildSession(
        id: 's3',
        title: 'Session',
        date: DateTime(2024, 1, 27),
        records: [
          record('Priya Patel', AttendanceStatus.absent, now),
          record('Mateo Rivera', AttendanceStatus.present, now),
        ],
      ),
    ];

    final analytics = calculateAttendanceAnalytics(
      sessions: sessions,
      families: families,
      range: AnalyticsRange.last30Days.resolve(now),
    );

    final patelFamily = analytics.families['fam-2']!;
    expect(patelFamily.attendanceRate, 0);
    expect(analytics.watchlist.any((flag) => flag.subject == 'Patel'), isTrue);
    expect(analytics.attendees['Priya Patel']!.absenceStreak, 3);
  });
}
