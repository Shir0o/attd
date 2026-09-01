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

// ─────────────────────────────────────────────────────────────────────────────
// Fast-marking search helpers
//
// Pure query/index logic shared by the fast marking surfaces (rapid entry,
// households, initials pad). Kept here beside SessionRoster so the marking
// modes add no new module of their own.
// ─────────────────────────────────────────────────────────────────────────────

/// How well [haystack] matches [query] — **lower is better**:
///
/// * `0` — [haystack] starts with the query
/// * `1` — a later word in [haystack] starts with the query
/// * `2` — the query appears somewhere else inside [haystack]
///
/// `null` when the query does not appear at all, and for a blank query (a
/// fast-marking search shows nothing until you type).
int? matchRank(String haystack, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return null;
  final h = haystack.toLowerCase();
  final at = h.indexOf(q);
  if (at < 0) return null;
  if (at == 0) return 0;
  // A word prefix is a match preceded by whitespace or a name separator.
  for (var i = at; i >= 0; i = h.indexOf(q, i + 1)) {
    if (i <= 0) continue;
    final before = h[i - 1];
    if (before == ' ' || before == '-' || before == "'") return 1;
  }
  return 2;
}

/// The first-name and surname initials of [displayName].
///
/// The surname is the last whitespace-separated token; a one-word name yields
/// that word's letter for both. A blank name yields empty initials.
({String first, String last}) nameInitials(String displayName) {
  final parts = displayName
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return (first: '', last: '');
  return (
    first: parts.first[0].toUpperCase(),
    last: parts.last[0].toUpperCase(),
  );
}

/// First-name initial → the surname initials available under it.
///
/// Drives the initials pad: the keys are the letters live at the first stage,
/// and the set under a picked letter is what stays live at the second.
/// Members with a blank display name are skipped.
Map<String, Set<String>> initialsIndex(Iterable<Member> members) {
  final index = <String, Set<String>>{};
  for (final m in members) {
    final initials = nameInitials(m.displayName);
    if (initials.first.isEmpty) continue;
    index.putIfAbsent(initials.first, () => <String>{}).add(initials.last);
  }
  return index;
}

/// One roster entry a fast-marking search can return — a member, plus the
/// family they belong to when there is one.
typedef SearchEntry = ({Member member, String? familyName});

/// How well one [entry] matches [query] — lower is better, `null` for no
/// match. A family-name match always ranks worse than any display-name match.
int? searchRank(SearchEntry entry, String query) {
  final byName = matchRank(entry.member.displayName, query);
  if (byName != null) return byName;
  final familyName = entry.familyName;
  if (familyName == null) return null;
  final byFamily = matchRank(familyName, query);
  return byFamily == null ? null : byFamily + 3;
}

/// The [entries] matching [query], best match first.
///
/// A display-name match always beats a family-name match; within a tier an
/// exact prefix beats a word prefix beats a substring. Remaining ties break on
/// [priority] (lower first; an entry missing from the map sorts after every
/// entry in it) and finally on display name. A blank query returns nothing.
List<SearchEntry> rankedSearch(
  Iterable<SearchEntry> entries,
  String query, {
  Map<String, int> priority = const {},
}) {
  if (query.trim().isEmpty) return const [];

  final scored = <({SearchEntry entry, int rank})>[];
  for (final entry in entries) {
    final rank = searchRank(entry, query);
    if (rank == null) continue;
    scored.add((entry: entry, rank: rank));
  }

  scored.sort((a, b) {
    if (a.rank != b.rank) return a.rank.compareTo(b.rank);
    final pa = priority[a.entry.member.id];
    final pb = priority[b.entry.member.id];
    if (pa != pb) {
      if (pa == null) return 1;
      if (pb == null) return -1;
      return pa.compareTo(pb);
    }
    return a.entry.member.displayName.toLowerCase().compareTo(
          b.entry.member.displayName.toLowerCase(),
        );
  });

  return [for (final s in scored) s.entry];
}
