import '../../../data/session.dart';
import '../models/attendance_status.dart';

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
