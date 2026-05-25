import '../../../data/session.dart';
import '../../../data/session_record.dart';
import '../models/attendance_start_mode.dart';
import '../models/attendance_status.dart';
import '../models/member.dart';
import 'member_default_resolver.dart';

/// Returns a list of pre-seeded SessionRecords for [members] given a start mode.
///
/// - [AttendanceStartMode.allAbsent] marks every member absent.
/// - [AttendanceStartMode.allPresent] marks every member present.
/// - [AttendanceStartMode.perMemberDefault] uses past-pattern based defaults
///   when [recentSessions] is supplied (members whose history is mixed or
///   sparse are *skipped* so the deck still asks). Falls back to each
///   member's static `defaultStatus` when no history is provided.
///
/// Skips members whose id is empty (defensive — those shouldn't be in an
/// event roster, but we don't want to create blank records if they slip in).
List<SessionRecord> buildPreseededRecords({
  required Iterable<Member> members,
  required AttendanceStartMode mode,
  required DateTime recordedAt,
  String recordedBy = 'System (Preseed)',
  List<Session> recentSessions = const [],
}) {
  final records = <SessionRecord>[];
  for (final member in members) {
    if (member.id.trim().isEmpty) continue;
    AttendanceStatus? status;
    switch (mode) {
      case AttendanceStartMode.allAbsent:
        status = AttendanceStatus.absent;
        break;
      case AttendanceStartMode.allPresent:
        status = AttendanceStatus.present;
        break;
      case AttendanceStartMode.perMemberDefault:
        if (recentSessions.isEmpty) {
          status = member.defaultStatus;
        } else {
          final resolved = resolveDefault(member.id, recentSessions);
          switch (resolved) {
            case ResolvedDefault.present:
              status = AttendanceStatus.present;
              break;
            case ResolvedDefault.absent:
              status = AttendanceStatus.absent;
              break;
            case ResolvedDefault.ask:
              // Leave un-recorded so the deck prompts for this member.
              status = null;
              break;
          }
        }
        break;
    }
    if (status == null) continue;
    records.add(
      SessionRecord(
        memberId: member.id,
        attendee: member.displayName,
        status: status,
        recordedAt: recordedAt,
        recordedBy: recordedBy,
      ),
    );
  }
  return records;
}
