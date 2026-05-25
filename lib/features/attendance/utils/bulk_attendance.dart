import '../../../data/session_record.dart';
import '../models/attendance_status.dart';
import '../models/member.dart';

/// Returns a new record list with every entry for [members] replaced by a
/// single status. Records belonging to members *not* in [members] are kept
/// verbatim so unrelated visitors aren't clobbered.
///
/// The same helper is used by the deck list-mode and the session summary's
/// "Mark everyone present/absent" actions so their behavior stays in sync.
List<SessionRecord> applyBulkRecords({
  required List<SessionRecord> previousRecords,
  required Iterable<Member> members,
  required bool present,
  required DateTime recordedAt,
  String recordedBy = 'User (Bulk)',
}) {
  final memberList = members.toList(growable: false);
  final status =
      present ? AttendanceStatus.present : AttendanceStatus.absent;
  final memberIds = memberList
      .where((m) => !m.isVisitor && m.id.trim().isNotEmpty)
      .map((m) => m.id)
      .toSet();
  final memberNames = memberList.map((m) => m.displayName).toSet();

  final updated = <SessionRecord>[];
  for (final r in previousRecords) {
    final byId = r.memberId != null && memberIds.contains(r.memberId);
    final byName = r.memberId == null && memberNames.contains(r.attendee);
    if (byId || byName) continue;
    updated.add(r);
  }
  for (final m in memberList) {
    final mid = (m.isVisitor || m.id.trim().isEmpty) ? null : m.id;
    updated.add(SessionRecord(
      memberId: mid,
      attendee: m.displayName,
      status: status,
      recordedAt: recordedAt,
      recordedBy: recordedBy,
    ));
  }
  return updated;
}
