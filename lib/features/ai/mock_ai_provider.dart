import 'dart:math' as math;

import 'package:attendance_tracker/features/ai/ai_provider.dart';

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

    final normalizedSubject = request.flag.subject.trim();
    final suggestedName = normalizedSubject.isEmpty
        ? 'Community member'
        : normalizedSubject.split(' ').map(_titleCase).join(' ');
    final duplicateClusterIds = [
      'cluster-${normalizedSubject.hashCode.abs() % 3}',
    ];

    return FollowUpSuggestion(
      subject: request.flag.subject,
      message: message,
      reasoning:
          'Generated from ${request.analytics.range.label} watchlist signal: ${request.flag.reason}.',
      tone: tone,
      nameSuggestion: NameSuggestion(
        suggestedName: suggestedName,
        confidence: 0.72,
        duplicateClusterIds: duplicateClusterIds,
      ),
      duplicateClusterIds: duplicateClusterIds,
      subjectLabel: SubjectLabel(
        label: request.flag.isFamily
            ? 'Family outreach'
            : 'Individual follow-up',
        rationale: 'Flagged from ${request.analytics.range.label} trends.',
      ),
      label: request.flag.isFamily ? 'Family outreach' : 'Individual follow-up',
      labelRationale: 'Supports migration to the labelRationale API.',
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
      final partialPenalty = 0.0;
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
                'Recent pattern: ${insight.absenceStreak} absences over ${insight.total} sessions.',
            probability: double.parse(probability.toStringAsFixed(2)),
            nameSuggestion: NameSuggestion(
              suggestedName: _titleCase(name),
              confidence: 0.65,
              duplicateClusterIds: ['cluster-${name.hashCode.abs() % 5}'],
            ),
            duplicateClusterIds: ['cluster-${name.hashCode.abs() % 5}'],
            subjectLabel: const SubjectLabel(
              label: 'High risk',
              rationale: 'Multiple consecutive absences detected.',
            ),
            label: 'High risk',
            labelRationale: 'Multiple consecutive absences detected.',
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
            nameSuggestion: NameSuggestion(
              suggestedName: _titleCase(family.family.displayName),
              confidence: 0.58,
              duplicateClusterIds: ['cluster-${family.family.id}'],
            ),
            duplicateClusterIds: ['cluster-${family.family.id}'],
            subjectLabel: const SubjectLabel(
              label: 'Family risk',
              rationale: 'Attendance below desired threshold.',
            ),
            label: 'Family risk',
            labelRationale: 'Attendance below desired threshold.',
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

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }
}
