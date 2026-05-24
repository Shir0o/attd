import '../../../data/session_record.dart';
import '../models/attendance_start_mode.dart';
import '../models/attendance_status.dart';
import '../models/member.dart';

/// Returns a list of pre-seeded SessionRecords for [members] given a start mode.
///
/// - [AttendanceStartMode.allAbsent] marks every member absent.
/// - [AttendanceStartMode.allPresent] marks every member present.
/// - [AttendanceStartMode.perMemberDefault] uses each member's
///   `defaultStatus`.
///
/// Skips members whose id is empty (defensive — those shouldn't be in an
/// event roster, but we don't want to create blank records if they slip in).
List<SessionRecord> buildPreseededRecords({
  required Iterable<Member> members,
  required AttendanceStartMode mode,
  required DateTime recordedAt,
  String recordedBy = 'System (Preseed)',
}) {
  final records = <SessionRecord>[];
  for (final member in members) {
    if (member.id.trim().isEmpty) continue;
    final AttendanceStatus status;
    switch (mode) {
      case AttendanceStartMode.allAbsent:
        status = AttendanceStatus.absent;
        break;
      case AttendanceStartMode.allPresent:
        status = AttendanceStatus.present;
        break;
      case AttendanceStartMode.perMemberDefault:
        status = member.defaultStatus;
        break;
    }
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
