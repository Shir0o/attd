import 'dart:math' as math;

import 'package:attendance_tracker/features/ai/ai_provider.dart';
import 'package:attendance_tracker/features/analytics/attendance_analytics.dart';

class MockAiProvider implements AiProvider {
  const MockAiProvider({this.latency = const Duration(milliseconds: 250)});

  final Duration latency;

  @override
  Future<FollowUpSuggestion> suggestFollowUp(FollowUpRequest request) async {
    await Future<void>.delayed(latency);
    final tone = request.flag.isFamily
        ? 'gentle family outreach'
        : 'caring check-in';
    final honorific = request.flag.isFamily ? 'family' : 'there';
    final encouragement = request.flag.reason.contains('absences')
        ? 'We miss seeing you and hope everything is okay.'
        : 'We want to make sure you are supported and informed.';

    final message = [
      'Hi $honorific,',
      request.flag.isFamily
          ? 'This is a quick wellness check for ${request.flag.subject}.'
          : 'This is a quick note for ${request.flag.subject}.',
      request.flag.reason,
      encouragement,
      'Please let us know if there is anything you need or any schedule changes we should know about.',
      'Warmly,\nThe attendance team',
    ].join(' ');

    return FollowUpSuggestion(
      subject: request.flag.subject,
      message: message,
      reasoning:
          'Generated from ${request.analytics.range.label} watchlist signal: ${request.flag.reason}.',
      tone: tone,
    );
  }

  @override
  Future<List<AbsencePrediction>> predictAbsences(
    AbsencePredictionRequest request,
  ) async {
    await Future<void>.delayed(latency);
    final predictions = <AbsencePrediction>[];

    request.analytics.attendees.forEach((name, insight) {
      final absenceMomentum = _streakMomentum(insight.absenceStreak);
      final partialPenalty = math.min(insight.lateStreak * 0.05, 0.15);
      final denominator = math.max(insight.total, 1);
      final absenceRate = insight.absent / denominator;
      final probability = math.min(
        1.0,
        absenceMomentum + partialPenalty + absenceRate * 0.5,
      );
      if (probability >= request.minConfidence) {
        predictions.add(
          AbsencePrediction(
            subject: name,
            reason:
                'Recent pattern: ${insight.absenceStreak} absences, ${insight.lateStreak} late arrivals over ${insight.total} sessions.',
            probability: double.parse(probability.toStringAsFixed(2)),
          ),
        );
      }
    });

    for (final family in request.analytics.families.values) {
      final denominator = math.max(family.total, 1);
      final absenceRate = family.absent / denominator;
      final probability = math.min(1.0, 0.3 + absenceRate * 0.7);
      if (probability >= request.minConfidence) {
        predictions.add(
          AbsencePrediction(
            subject: family.family.displayName,
            reason:
                'Family attendance at ${family.attendanceRate.toStringAsFixed(0)}%.',
            probability: double.parse(probability.toStringAsFixed(2)),
            isFamily: true,
          ),
        );
      }
    }

    predictions.sort((a, b) => b.probability.compareTo(a.probability));
    return predictions;
  }

  double _streakMomentum(int streak) {
    if (streak == 0) return 0.1;
    if (streak == 1) return 0.2;
    if (streak == 2) return 0.35;
    if (streak >= 3) return 0.55;
    return 0.1;
  }
}
