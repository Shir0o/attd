import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/ai/ai_provider.dart';
import 'package:attendance_tracker/features/ai/mock_ai_provider.dart';
import 'package:attendance_tracker/features/analytics/attendance_analytics.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const provider = MockAiProvider(latency: Duration.zero);
  final today = DateTime(2025, 1, 15);
  final range = AnalyticsRange.last30Days.resolve(today);

  final families = [
    Family(
      id: 'fam-1',
      displayName: 'Lee family',
      members: const [
        Member(
          id: 'm1',
          displayName: 'Alex',
          defaultStatus: AttendanceStatus.absent,
        ),
        Member(
          id: 'm2',
          displayName: 'Jordan',
          defaultStatus: AttendanceStatus.present,
        ),
      ],
    ),
  ];

  final sessions = [
    Session(
      id: 's1',
      title: 'Weekly meetup',
      sessionDate: today.subtract(const Duration(days: 2)),
      records: [
        SessionRecord(
          attendee: 'Alex',
          status: AttendanceStatus.absent,
          recordedAt: DateTime(2025, 1, 13),
          recordedBy: 'coach',
        ),
        SessionRecord(
          attendee: 'Jordan',
          status: AttendanceStatus.present,
          recordedAt: DateTime(2025, 1, 13),
          recordedBy: 'coach',
        ),
      ],
      createdAt: today,
      updatedAt: today,
      createdBy: 'coach',
    ),
    Session(
      id: 's2',
      title: 'Weekend check-in',
      sessionDate: today.subtract(const Duration(days: 1)),
      records: [
        SessionRecord(
          attendee: 'Alex',
          status: AttendanceStatus.absent,
          recordedAt: DateTime(2025, 1, 14),
          recordedBy: 'coach',
        ),
        SessionRecord(
          attendee: 'Jordan',
          status: AttendanceStatus.present,
          recordedAt: DateTime(2025, 1, 14),
          recordedBy: 'coach',
        ),
      ],
      createdAt: today,
      updatedAt: today,
      createdBy: 'coach',
    ),
  ];

  final analytics = calculateAttendanceAnalytics(
    sessions: sessions,
    families: families,
    range: range,
  );

  test(
    'suggestFollowUp returns a compassionate message with reasoning',
    () async {
      final request = FollowUpRequest(
        flag: analytics.watchlist.first,
        analytics: analytics,
        sessions: sessions,
        rangeLabel: range.label,
        family: families.first,
      );

      final suggestion = await provider.suggestFollowUp(request);

      expect(suggestion.subject, equals(request.flag.subject));
      expect(suggestion.message.toLowerCase(), contains('please'));
      expect(suggestion.reasoning, contains(request.flag.reason));
    },
  );

  test(
    'predictAbsences highlights members with consecutive absences',
    () async {
      final predictions = await provider.predictAbsences(
        AbsencePredictionRequest(analytics: analytics, sessions: sessions),
      );

      final alexPrediction = predictions.firstWhere(
        (prediction) => prediction.subject == 'Alex',
      );
      expect(alexPrediction.probability, greaterThanOrEqualTo(0.35));
      expect(alexPrediction.reason, contains('absences'));
    },
  );

  test('buildNameMetadata captures usage counts and normalized variants', () {
    final metadata = buildNameMetadata(
      sessions: sessions,
      analytics: analytics,
      families: families,
    );

    expect(metadata['Alex']?.normalized, equals('alex'));
    expect(metadata['Alex']?.usageCount, equals(2));
    expect(metadata['Lee family']?.usageCount, equals(0));
  });

  test('buildAttendanceLabelFeatures summarizes streaks and recency', () {
    final features = buildAttendanceLabelFeatures(
      sessions: sessions,
      analytics: analytics,
      families: families,
    );

    final alexFeatures = features['Alex'];
    expect(alexFeatures?.absentCount, equals(2));
    expect(alexFeatures?.presentCount, equals(0));
    expect(
      alexFeatures?.absenceStreak,
      equals(analytics.attendees['Alex']!.absenceStreak),
    );
    expect(alexFeatures?.lastRecorded, equals(DateTime(2025, 1, 14)));

    final familyFeatures = features['Lee family'];
    expect(familyFeatures?.totalSessions, equals(4));
    expect(familyFeatures?.lastRecorded, equals(DateTime(2025, 1, 14)));
  });
}
