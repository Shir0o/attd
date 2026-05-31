import '../../../data/session.dart';
import '../../../data/session_record.dart';
import '../models/attendance_status.dart';
import '../models/member.dart';

class SessionRoster {
  final Map<String, SessionRecord> recordByMemberId = {};
  final Map<String, SessionRecord> recordByVisitorName = {};
  final Map<String, Member> displayMembersMap = {};

  SessionRoster(Session session, List<Member> baseMembers) {
    for (final r in session.records) {
      final mid = r.memberId;
      if (mid != null && mid.trim().isNotEmpty) {
        recordByMemberId[mid] = r;
      } else {
        recordByVisitorName[r.attendee] = r;
      }
    }

    final excludedIds = session.excludedMemberIds.toSet();

    for (final m in baseMembers) {
      if (excludedIds.contains(m.id)) continue;

      final record =
          recordByMemberId[m.id] ?? recordByVisitorName[m.displayName];
      if (record != null) {
        // Snapshot invariant: a recorded session displays the name captured on
        // `record.attendee` at record time, NOT the member's current name.
        // Renaming a member in the member list therefore never rewrites past
        // sessions; corrections to a historical session are made per-session
        // (see SessionSummaryPage._editMemberName). Keep this read sourced from
        // the record, not from `m.displayName`.
        displayMembersMap[m.id] = Member(
          id: m.id,
          displayName: record.attendee,
          isVisitor: false,
        );
      } else {
        displayMembersMap[m.id] = m;
      }
    }

    final memberNames = baseMembers.map((m) => m.displayName).toSet();
    for (final record in session.records) {
      final mid = record.memberId;
      final hasValidId = mid != null && mid.trim().isNotEmpty;
      if (hasValidId) {
        if (!displayMembersMap.containsKey(mid) &&
            !excludedIds.contains(mid)) {
          displayMembersMap[mid] = Member(
            id: mid,
            displayName: record.attendee,
            isVisitor: false,
          );
        }
      } else {
        if (!memberNames.contains(record.attendee)) {
          final visitorId = 'visitor_${record.attendee}';
          if (!displayMembersMap.containsKey(visitorId)) {
            displayMembersMap[visitorId] = Member(
              id: visitorId,
              displayName: record.attendee,
              isVisitor: true,
            );
          }
        }
      }
    }
  }

  AttendanceStatus getStatus(Member member) {
    if (member.isVisitor) {
      return recordByVisitorName[member.displayName]?.status ??
          AttendanceStatus.absent;
    } else {
      if (member.id.trim().isEmpty) {
        return recordByVisitorName[member.displayName]?.status ??
            AttendanceStatus.absent;
      }
      return recordByMemberId[member.id]?.status ??
          recordByVisitorName[member.displayName]?.status ??
          AttendanceStatus.absent;
    }
  }

  List<Member> get sortedMembers {
    return displayMembersMap.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }
}
