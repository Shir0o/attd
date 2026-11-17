import '../../../../data/session_record.dart';
import '../../attendance/models/attendance_status.dart';
import 'handoff_file.dart';
import 'mark_merge.dart';

/// What importing a result would do to one session.
class ImportPlan {
  const ImportPlan({
    required this.records,
    required this.changed,
    required this.unknownMemberMarks,
  });

  /// The records the session should end up with.
  final List<SessionRecord> records;

  /// False when every incoming mark was already there (a repeated import).
  final bool changed;

  /// Marks whose member no longer exists, kept as guest marks by name.
  final int unknownMemberMarks;
}

abstract final class HandoffImport {
  /// Turns a result into session records. [knownMembers] maps the ids of
  /// members that still exist on the owner's phone to their display names.
  /// A mark for any other id becomes a guest mark by name rather than being
  /// dropped. Only present marks can become guests: an absent mark for
  /// someone who no longer exists says nothing worth keeping.
  static ImportPlan plan({
    required HandoffResult result,
    required Map<String, String> knownMembers,
    required List<SessionRecord> existing,
  }) {
    final incoming = <SessionRecord>[];
    var unknown = 0;
    for (final mark in result.marks) {
      final knownName = knownMembers[mark.memberId];
      if (knownName != null) {
        incoming.add(SessionRecord(
          memberId: mark.memberId,
          attendee: knownName,
          status: mark.status,
          recordedAt: mark.recordedAt,
          recordedBy: result.actor,
        ));
      } else if (mark.status == AttendanceStatus.present) {
        unknown++;
        incoming.add(SessionRecord(
          attendee: mark.name,
          status: AttendanceStatus.present,
          recordedAt: mark.recordedAt,
          recordedBy: result.actor,
        ));
      }
    }
    for (final guest in result.guests) {
      incoming.add(SessionRecord(
        attendee: guest.name,
        status: AttendanceStatus.present,
        recordedAt: guest.recordedAt,
        recordedBy: result.actor,
      ));
    }

    final merged = MarkMerge.mergeRecordLists(existing, incoming);
    var changed = merged.length != existing.length;
    for (var i = 0; !changed && i < merged.length; i++) {
      changed = !identical(merged[i], existing[i]);
    }
    return ImportPlan(
      records: merged,
      changed: changed,
      unknownMemberMarks: unknown,
    );
  }
}
