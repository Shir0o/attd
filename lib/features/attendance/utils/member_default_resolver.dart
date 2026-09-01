import '../../../data/session.dart';
import '../models/attendance_status.dart';
import '../models/member.dart';

/// Window and threshold for past-pattern based defaults.
/// Tunable here; no settings UI for now.
const int kPatternWindow = 8;
const double kPatternThreshold = 0.8;
const int kPatternMinSamples = 3;

enum ResolvedDefault { present, absent, ask }

/// Resolves a per-member default from recent attendance history.
///
/// - ≥80% present over the last 8 sessions → [ResolvedDefault.present]
/// - ≥80% absent over the last 8 sessions → [ResolvedDefault.absent]
/// - Otherwise (mixed or fewer than 3 samples) → [ResolvedDefault.ask]
///
/// "Ask" means the caller should skip pre-seeding the member so the deck
/// still prompts for them.
///
/// [recentSessions] should be passed newest-first; only the first
/// [kPatternWindow] are consulted.
ResolvedDefault resolveDefault(
  String memberId,
  List<Session> recentSessions,
) {
  final statuses = <AttendanceStatus>[];
  for (final session in recentSessions.take(kPatternWindow)) {
    for (final record in session.records) {
      if (record.memberId == memberId) {
        statuses.add(record.status);
        break;
      }
    }
  }
  if (statuses.length < kPatternMinSamples) return ResolvedDefault.ask;
  final presentRatio = statuses
          .where((s) => s == AttendanceStatus.present)
          .length /
      statuses.length;
  if (presentRatio >= kPatternThreshold) return ResolvedDefault.present;
  if (presentRatio <= 1 - kPatternThreshold) return ResolvedDefault.absent;
  return ResolvedDefault.ask;
}

/// A member's recent attendance rate over the last [kPatternWindow] sessions,
/// or `null` when fewer than [kPatternMinSamples] of them recorded the member.
///
/// [recentSessions] should be passed newest-first, as for [resolveDefault].
double? attendanceRate(String memberId, List<Session> recentSessions) {
  var samples = 0;
  var present = 0;
  for (final session in recentSessions.take(kPatternWindow)) {
    for (final record in session.records) {
      if (record.memberId == memberId) {
        samples++;
        if (record.status == AttendanceStatus.present) present++;
        break;
      }
    }
  }
  if (samples < kPatternMinSamples) return null;
  return present / samples;
}

/// Orders [members] by how likely each is to be at this session.
///
/// Highest recent attendance rate first; members without enough history to
/// rank ([attendanceRate] returning `null`) follow every ranked member, and
/// display name breaks any remaining tie. Never mutates [members].
List<Member> rankByLikelihood(
  List<Member> members,
  List<Session> recentSessions,
) {
  final rates = <String, double?>{
    for (final m in members) m.id: attendanceRate(m.id, recentSessions),
  };
  return members.toList()
    ..sort((a, b) {
      final ra = rates[a.id];
      final rb = rates[b.id];
      if (ra != rb) {
        if (ra == null) return 1;
        if (rb == null) return -1;
        return rb.compareTo(ra);
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
}
