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
    this.nameMetadata = const {},
    this.attendanceFeatures = const {},
  });

  final WellnessFlag flag;
  final AttendanceAnalytics analytics;
  final List<Session> sessions;
  final String rangeLabel;
  final Family? family;
  final Map<String, NameMetadata> nameMetadata;
  final Map<String, AttendanceLabelFeatures> attendanceFeatures;
}

class FollowUpSuggestion {
  const FollowUpSuggestion({
    required this.subject,
    required this.message,
    required this.reasoning,
    required this.tone,
    this.correctedName,
    this.duplicateCandidates = const [],
    this.label,
    this.labelReason,
  });

  final String subject;
  final String message;
  final String reasoning;
  final String tone;
  final String? correctedName;
  final List<String> duplicateCandidates;
  final String? label;
  final String? labelReason;
}

class AbsencePredictionRequest {
  const AbsencePredictionRequest({
    required this.analytics,
    required this.sessions,
    this.minConfidence = 0.25,
    this.nameMetadata = const {},
    this.attendanceFeatures = const {},
  });

  final AttendanceAnalytics analytics;
  final List<Session> sessions;
  final double minConfidence;
  final Map<String, NameMetadata> nameMetadata;
  final Map<String, AttendanceLabelFeatures> attendanceFeatures;
}

class AbsencePrediction {
  const AbsencePrediction({
    required this.subject,
    required this.reason,
    required this.probability,
    this.isFamily = false,
    this.correctedName,
    this.duplicateCandidates = const [],
    this.label,
    this.labelReason,
  }) : assert(probability >= 0 && probability <= 1);

  final String subject;
  final String reason;
  final double probability;
  final bool isFamily;
  final String? correctedName;
  final List<String> duplicateCandidates;
  final String? label;
  final String? labelReason;
}

class NameMetadata {
  const NameMetadata({
    required this.original,
    required this.normalized,
    this.recentEdits = const [],
    this.usageCount = 0,
  });

  final String original;
  final String normalized;
  final List<String> recentEdits;
  final int usageCount;

  Map<String, dynamic> toJson() {
    return {
      'original': original,
      'normalized': normalized,
      'recentEdits': recentEdits,
      'usageCount': usageCount,
    };
  }
}

class AttendanceLabelFeatures {
  const AttendanceLabelFeatures({
    required this.totalSessions,
    required this.absentCount,
    required this.presentCount,
    this.absenceStreak,
    this.lastRecorded,
  });

  final int totalSessions;
  final int absentCount;
  final int presentCount;
  final int? absenceStreak;
  final DateTime? lastRecorded;

  Map<String, dynamic> toJson() {
    return {
      'totalSessions': totalSessions,
      'absentCount': absentCount,
      'presentCount': presentCount,
      if (absenceStreak != null) 'absenceStreak': absenceStreak,
      if (lastRecorded != null) 'lastRecorded': lastRecorded!.toIso8601String(),
    };
  }
}

Map<String, NameMetadata> buildNameMetadata({
  required List<Session> sessions,
  required AttendanceAnalytics analytics,
  List<Family> families = const [],
}) {
  final usage = <String, int>{};
  final normalizedVariants = <String, Set<String>>{};

  for (final session in sessions) {
    for (final record in session.records) {
      final name = record.attendee;
      final normalized = name.trim().toLowerCase();
      usage[name] = (usage[name] ?? 0) + 1;
      normalizedVariants.putIfAbsent(normalized, () => <String>{});
      normalizedVariants[normalized]!.add(name);
    }
  }

  final knownNames = <String>{
    ...usage.keys,
    ...analytics.attendees.keys,
    ...analytics.families.values.map((family) => family.family.displayName),
    ...analytics.watchlist.map((flag) => flag.subject),
    ...families.expand(
      (family) => family.members.map((member) => member.displayName),
    ),
  };

  final metadata = <String, NameMetadata>{};
  for (final name in knownNames) {
    final normalized = name.trim().toLowerCase();
    final variants = normalizedVariants[normalized] ?? {name};
    metadata[name] = NameMetadata(
      original: name,
      normalized: normalized,
      recentEdits: variants.where((variant) => variant != name).toList(),
      usageCount: usage[name] ?? 0,
    );
  }

  return metadata;
}

Map<String, AttendanceLabelFeatures> buildAttendanceLabelFeatures({
  required List<Session> sessions,
  required AttendanceAnalytics analytics,
  List<Family> families = const [],
}) {
  final lastRecordedByAttendee = <String, DateTime?>{};
  for (final session in sessions) {
    for (final record in session.records) {
      final current = lastRecordedByAttendee[record.attendee];
      if (current == null || session.sessionDate.isAfter(current)) {
        lastRecordedByAttendee[record.attendee] = session.sessionDate;
      }
    }
  }

  final features = <String, AttendanceLabelFeatures>{};

  analytics.attendees.forEach((name, insight) {
    features[name] = AttendanceLabelFeatures(
      totalSessions: insight.total,
      absentCount: insight.absent,
      presentCount: insight.present,
      absenceStreak: insight.absenceStreak,
      lastRecorded: lastRecordedByAttendee[name],
    );
  });

  for (final familyInsight in analytics.families.values) {
    final mostRecentMemberRecord = familyInsight.family.members
        .map((member) => lastRecordedByAttendee[member.displayName])
        .whereType<DateTime>()
        .fold<DateTime?>(null, (previous, current) {
          if (previous == null) return current;
          if (current.isAfter(previous)) return current;
          return previous;
        });

    features[familyInsight.family.displayName] = AttendanceLabelFeatures(
      totalSessions: familyInsight.total,
      absentCount: familyInsight.absent,
      presentCount: familyInsight.present,
      lastRecorded: mostRecentMemberRecord,
    );
  }

  return features;
}
