import 'dart:convert';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/features/ai/ai_provider.dart';
import 'package:attendance_tracker/features/ai/http_ai_provider.dart';
import 'package:attendance_tracker/features/analytics/attendance_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final endpoint = Uri.parse('https://example.com/ai');
  final range = AnalyticsRange.last30Days.resolve(DateTime(2025, 1, 15));
  final analytics = AttendanceAnalytics(
    breakdown: AttendanceBreakdown(present: 0, absent: 0),
    attendees: {},
    families: {},
    trend: [],
    watchlist: [WellnessFlag(subject: 'Alex', reason: 'Two absences')],
    range: AnalyticsDateRange(
      start: DateTime(2025, 1, 1),
      end: DateTime(2025, 1, 30),
      label: 'Custom',
    ),
  );

  const sessions = <Session>[];

  test('suggestFollowUp parses corrected names, duplicates, and labels', () async {
    final client = MockClient((request) async {
      expect(request.method, equals('POST'));
      return http.Response(
        jsonEncode({
          'subject': 'Alex',
          'message': 'Please check in kindly.',
          'reasoning': 'Several absences detected',
          'tone': 'compassionate',
          'correctedName': 'Alexander',
          'duplicateCandidates': ['Alex R', 42],
          'duplicateClusterIds': ['cluster-a', 99],
          'label': 'High risk',
          'labelRationale': 'Recent streak',
          'nameSuggestion': {
            'suggestedName': 'Alexander',
            'confidence': 0.92,
            'duplicateClusterIds': ['cluster-b'],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final provider = HttpAiProvider(endpoint: endpoint, client: client);
    final suggestion = await provider.suggestFollowUp(
      FollowUpRequest(
        flag: analytics.watchlist.first,
        analytics: analytics,
        sessions: sessions,
        rangeLabel: range.label,
      ),
    );

    expect(suggestion.correctedName, equals('Alexander'));
    expect(suggestion.duplicateCandidates, equals(['Alex R']));
    expect(suggestion.duplicateClusterIds, equals(['cluster-a']));
    expect(suggestion.label, equals('High risk'));
    expect(suggestion.labelRationale, equals('Recent streak'));
    expect(suggestion.nameSuggestion?.confidence, closeTo(0.92, 1e-2));
    expect(
      suggestion.nameSuggestion?.duplicateClusterIds,
      equals(['cluster-b']),
    );
  });

  test('predictAbsences filters by confidence and extracts name insights', () async {
    final client = MockClient((_) async {
      return http.Response(
        jsonEncode({
          'predictions': [
            {
              'subject': 'Alex',
              'reason': 'High risk due to absences',
              'probability': 0.9,
              'correctedName': 'Alexander',
              'duplicateCandidates': ['Alex R', 123],
              'duplicateClusterIds': ['cluster-1', true],
              'label': 'High risk',
              'labelReason': 'Attendance streak',
              'nameSuggestion': {
                'suggestedName': 'Alexander',
                'confidence': 0.87,
                'duplicateClusterIds': ['cluster-2'],
              },
            },
            {
              'subject': 'Jordan',
              'reason': 'Low risk',
              'probability': 0.1,
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final provider = HttpAiProvider(endpoint: endpoint, client: client);
    final predictions = await provider.predictAbsences(
      AbsencePredictionRequest(
        analytics: analytics,
        sessions: sessions,
        minConfidence: 0.25,
      ),
    );

    expect(predictions, hasLength(1));
    final prediction = predictions.single;
    expect(prediction.subject, equals('Alex'));
    expect(prediction.correctedName, equals('Alexander'));
    expect(prediction.duplicateCandidates, equals(['Alex R']));
    expect(prediction.duplicateClusterIds, equals(['cluster-1']));
    expect(prediction.label, equals('High risk'));
    expect(prediction.labelRationale, equals('Attendance streak'));
    expect(prediction.nameSuggestion?.duplicateClusterIds, equals(['cluster-2']));
  });

  test('handles legacy responses without optional name or label fields', () async {
    final client = MockClient((_) async {
      return http.Response(
        jsonEncode({
          'subject': 'Alex',
          'message': 'Legacy response',
          'reasoning': 'No optional fields',
          'tone': 'neutral',
          'predictions': [
            {
              'subject': 'Alex',
              'reason': 'Legacy prediction',
              'probability': 0.6,
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final provider = HttpAiProvider(endpoint: endpoint, client: client);
    final suggestion = await provider.suggestFollowUp(
      FollowUpRequest(
        flag: analytics.watchlist.first,
        analytics: analytics,
        sessions: sessions,
        rangeLabel: range.label,
      ),
    );
    expect(suggestion.correctedName, isNull);
    expect(suggestion.nameSuggestion, isNull);
    expect(suggestion.label, isNull);
    expect(suggestion.labelRationale, isNull);

    final predictions = await provider.predictAbsences(
      AbsencePredictionRequest(analytics: analytics, sessions: sessions),
    );
    expect(predictions, isNotEmpty);
    expect(predictions.single.label, isNull);
    expect(predictions.single.labelRationale, isNull);
    expect(predictions.single.nameSuggestion, isNull);
  });
}
