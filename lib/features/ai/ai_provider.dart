import 'package:attendance_tracker/features/analytics/attendance_analytics.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/data/session.dart';

abstract class AiProvider {
  Future<FollowUpSuggestion> suggestFollowUp(FollowUpRequest request);

  Future<List<AbsencePrediction>> predictAbsences(
    AbsencePredictionRequest request,
  );
}

class FollowUpRequest {
  const FollowUpRequest({
    required this.flag,
    required this.analytics,
    required this.sessions,
    required this.rangeLabel,
    this.family,
  });

  final WellnessFlag flag;
  final AttendanceAnalytics analytics;
  final List<Session> sessions;
  final String rangeLabel;
  final Family? family;
}

class FollowUpSuggestion {
  const FollowUpSuggestion({
    required this.subject,
    required this.message,
    required this.reasoning,
    required this.tone,
  });

  final String subject;
  final String message;
  final String reasoning;
  final String tone;
}

class AbsencePredictionRequest {
  const AbsencePredictionRequest({
    required this.analytics,
    required this.sessions,
    this.minConfidence = 0.25,
  });

  final AttendanceAnalytics analytics;
  final List<Session> sessions;
  final double minConfidence;
}

class AbsencePrediction {
  const AbsencePrediction({
    required this.subject,
    required this.reason,
    required this.probability,
    this.isFamily = false,
  }) : assert(probability >= 0 && probability <= 1);

  final String subject;
  final String reason;
  final double probability;
  final bool isFamily;
}
