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
      if (r.memberId != null) {
        recordByMemberId[r.memberId!] = r;
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
      if (record.memberId != null) {
        if (!displayMembersMap.containsKey(record.memberId) &&
            !excludedIds.contains(record.memberId)) {
          displayMembersMap[record.memberId!] = Member(
            id: record.memberId!,
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
