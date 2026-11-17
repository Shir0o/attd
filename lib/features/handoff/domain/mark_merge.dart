import '../../../../data/session_record.dart';
import '../../attendance/models/attendance_status.dart';

/// Mark-level merge rules: present beats absent regardless of time; otherwise
/// the later mark wins.
abstract final class MarkMerge {
  static SessionRecord mergeRecords(SessionRecord a, SessionRecord b) {
    final aIsPresent = a.status == AttendanceStatus.present;
    final bIsPresent = b.status == AttendanceStatus.present;

    if (aIsPresent && !bIsPresent) return a;
    if (!aIsPresent && bIsPresent) return b;

    // Both present, or both absent: the latest recordedAt wins.
    return b.recordedAt.isAfter(a.recordedAt) ? b : a;
  }

  /// A member mark is keyed by member id, a guest mark by name.
  static String recordKey(SessionRecord r) =>
      r.memberId ?? 'guest:${r.attendee}';

  /// Merges [incoming] into [local]. Existing order is kept and unseen marks
  /// are appended. A surviving [local] record is returned as the same
  /// instance, so callers can detect "nothing changed" with `identical`.
  static List<SessionRecord> mergeRecordLists(
    List<SessionRecord> local,
    List<SessionRecord> incoming,
  ) {
    final byKey = <String, SessionRecord>{
      for (final r in local) recordKey(r): r,
    };
    for (final r in incoming) {
      final key = recordKey(r);
      final existing = byKey[key];
      byKey[key] = existing == null ? r : mergeRecords(existing, r);
    }
    return byKey.values.toList();
  }
}
