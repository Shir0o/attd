import '../../../data/session.dart';
import '../../../data/session_record.dart';
import '../models/attendance_status.dart';
import '../models/member.dart';
import 'member_default_resolver.dart';

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

/// Applies smart defaults to [members]: each member is resolved from
/// [recentSessions] (present if here ≥80% of the last 8 sessions, absent if
/// ≤20%, otherwise left untouched). Members with a mixed/sparse history keep
/// whatever status they already had in [previousRecords].
///
/// Returns the updated record list plus the count of members the smart guess
/// actually resolved (for the bulk-action snackbar). Visitors and id-less
/// members are skipped — smart defaults need a stable id to match history.
({List<SessionRecord> records, int resolved}) applyBulkSmartRecords({
  required List<SessionRecord> previousRecords,
  required Iterable<Member> members,
  required List<Session> recentSessions,
  required DateTime recordedAt,
  String recordedBy = 'User (Bulk - Smart)',
}) {
  final resolved = <String, ({String displayName, AttendanceStatus status})>{};
  for (final m in members) {
    if (m.isVisitor || m.id.trim().isEmpty) continue;
    switch (resolveDefault(m.id, recentSessions)) {
      case ResolvedDefault.present:
        resolved[m.id] =
            (displayName: m.displayName, status: AttendanceStatus.present);
      case ResolvedDefault.absent:
        resolved[m.id] =
            (displayName: m.displayName, status: AttendanceStatus.absent);
      case ResolvedDefault.ask:
        break; // leave the member's existing status untouched
    }
  }

  final updated = <SessionRecord>[];
  for (final r in previousRecords) {
    if (r.memberId != null && resolved.containsKey(r.memberId)) continue;
    updated.add(r);
  }
  resolved.forEach((memberId, info) {
    updated.add(SessionRecord(
      memberId: memberId,
      attendee: info.displayName,
      status: info.status,
      recordedAt: recordedAt,
      recordedBy: recordedBy,
    ));
  });

  return (records: updated, resolved: resolved.length);
}
