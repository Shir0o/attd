import '../../../data/session.dart';
import '../../../data/session_record.dart';
import '../domain/active_roster_index.dart';
import '../models/attendance_status.dart';
import '../models/member.dart';

export '../domain/active_roster_index.dart' show SearchEntry;

class SessionRoster {
  final Map<String, SessionRecord> recordByMemberId = {};
  final Map<String, SessionRecord> recordByVisitorName = {};
  final Map<String, Member> displayMembersMap = {};

  /// The key [displayMembersMap] holds [member] under: its id, or for an
  /// id-less visitor (a Guest Mark) its name snapshot.
  static String keyFor(Member member) => member.id.trim().isEmpty
      ? 'visitor_${member.displayName}'
      : member.id;

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

      // An id-less entry (a Guest Mark added mid-session) would otherwise
      // share the '' key with every other one. Key it by its name snapshot,
      // as id-less records are keyed below, and keep it a visitor so writes
      // still carry a null member ID.
      if (m.id.trim().isEmpty) {
        final visitorId = keyFor(m);
        displayMembersMap[visitorId] = Member(
          id: visitorId,
          displayName: m.displayName,
          isVisitor: true,
        );
        continue;
      }

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

// ─────────────────────────────────────────────────────────────────────────────
// Fast-marking search helpers (Delegating to ActiveRosterIndex)
// ─────────────────────────────────────────────────────────────────────────────

/// How well [haystack] matches [query] — **lower is better**:
///
/// * `0` — [haystack] starts with the query
/// * `1` — a later word in [haystack] starts with the query
/// * `2` — the query appears somewhere else inside [haystack]
///
/// `null` when the query does not appear at all, and for a blank query.
int? matchRank(String haystack, String query) =>
    ActiveRosterIndex.calculateMatchRank(haystack, query);

/// The last whitespace-separated token of [displayName], or the whole name if
/// single-token. Returns an empty string for blank input.
String memberLastName(String displayName) =>
    ActiveRosterIndex.extractLastName(displayName);

/// All whitespace-separated tokens except the last of [displayName], or the
/// whole name if single-token. Returns an empty string for blank input.
String memberGivenName(String displayName) =>
    ActiveRosterIndex.extractGivenName(displayName);

/// The first-name and surname initials of [displayName].
({String first, String last}) nameInitials(String displayName) =>
    ActiveRosterIndex.extractInitials(displayName);

/// First-name initial → the surname initials available under it.
Map<String, Set<String>> initialsIndex(Iterable<Member> members) =>
    ActiveRosterIndex(members: members.toList()).initialsIndex();

/// How well one [entry] matches [query] — lower is better, `null` for no
/// match. A family-name match always ranks worse than any display-name match.
int? searchRank(SearchEntry entry, String query) =>
    ActiveRosterIndex.calculateSearchRank(entry, query);

/// The [entries] matching [query], best match first.
List<SearchEntry> rankedSearch(
  Iterable<SearchEntry> entries,
  String query, {
  Map<String, int> priority = const {},
}) =>
    ActiveRosterIndex.executeRankedSearch(entries, query, priority: priority);

