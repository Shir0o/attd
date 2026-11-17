import '../../../../data/session_record.dart';
import '../../attendance/models/attendance_status.dart';
import 'handoff_file.dart';

/// Builds outgoing handoff and result files from app data. Pure: callers pass
/// plain values, not repositories.
abstract final class HandoffBuilder {
  static final RegExp _unsafe =
      RegExp(r'[\u0000-\u001F\u007F-\u009F\u202A-\u202E\u2066-\u2069]');

  /// Strips control characters, collapses whitespace and bounds the length so
  /// anything the owner has typed can be sent.
  static String cleanText(String value, int max) {
    final cleaned =
        value.replaceAll(_unsafe, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.length <= max ? cleaned : cleaned.substring(0, max).trim();
  }

  /// The roster goes out as `{id, name}` pairs only. Blank names and repeated
  /// ids are dropped.
  static HandoffRoster buildHandoff({
    required String eventId,
    required String eventTitle,
    required DateTime sessionDate,
    required Iterable<({String id, String name})> roster,
  }) {
    final seen = <String>{};
    final people = <HandoffPerson>[];
    for (final member in roster) {
      final name = cleanText(member.name, HandoffLimits.maxNameLength);
      if (name.isEmpty || !seen.add(member.id)) continue;
      people.add(HandoffPerson(id: member.id, name: name));
    }
    return HandoffRoster(
      eventId: eventId,
      eventTitle: cleanText(eventTitle, HandoffLimits.maxTitleLength),
      sessionDate: DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
      ),
      roster: people,
    );
  }

  /// Turns the helper's session records into a result for the owner.
  ///
  /// Records on a handed-off event carry [handoffIdPrefix] ids; the prefix is
  /// removed so the owner sees their own ids. Records without such an id
  /// (guest marks, or anything unexpected) go out as guests by name, and only
  /// present guests are sent.
  static HandoffResult buildResult({
    required String eventId,
    required DateTime sessionDate,
    required Iterable<SessionRecord> records,
    String? helperName,
  }) {
    final marks = <HandoffMark>[];
    final guests = <HandoffGuest>[];
    for (final record in records) {
      final sourceId = record.memberId == null
          ? null
          : HandoffRoster.sourceMemberId(record.memberId!);
      final name = cleanText(record.attendee, HandoffLimits.maxNameLength);
      if (name.isEmpty) continue;
      if (sourceId != null) {
        marks.add(HandoffMark(
          memberId: sourceId,
          name: name,
          status: record.status,
          recordedAt: record.recordedAt,
        ));
      } else if (record.status == AttendanceStatus.present) {
        guests.add(HandoffGuest(name: name, recordedAt: record.recordedAt));
      }
    }
    final helper = helperName == null
        ? null
        : cleanText(helperName, HandoffLimits.maxHelperNameLength);
    return HandoffResult(
      eventId: eventId,
      sessionDate: DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
      ),
      helperName: (helper == null || helper.isEmpty) ? null : helper,
      marks: marks,
      guests: guests,
    );
  }
}
