/// "Who to check on": fixed rules that flag roster members who need attention.
///
/// See docs/superpowers/specs/2026-11-15-who-to-check-on-design.md. Every
/// number lives here and is the same for every event; there are no settings.
///
/// "Missed" means no present mark (a late mark is present). Meetings are
/// counted back from the event's latest session, never from today, so an
/// event that has not met flags nobody new.
///
/// A person's meetings are the event's sessions that did not exclude them: an
/// exclusion is neither an attendance nor a miss.
///
/// The "weeks" rules (Gone quiet, One-time visitor) measure from the date
/// last present to the event's latest session date. For an event that meets
/// less often than weekly that span grows faster per missed meeting (6 weeks
/// is about 3 bi-weekly or 2 monthly meetings), and a long break in meetings
/// would make one missed meeting look like weeks away. So these rules also
/// require at least [kTimeRuleMinMisses] missed meetings since last present:
/// nobody is flagged just because the event itself has not met.
library;

import 'package:intl/intl.dart';

import '../../../data/session.dart';
import '../../attendance/models/attendance_status.dart';
import '../../attendance/models/member.dart';
import '../../hub/domain/event.dart';

/// Rule constants. Changing one changes it for every event.
const int kCheckOnMinSessions = 4;
const int kNotComingMinCame = 2;
const int kNotComingMisses = 3;
const int kDropPriorMeetings = 8;
const double kDropPriorRate = 0.75;
const int kDropRecentMeetings = 4;
const int kDropRecentMisses = 3;
const int kGoneQuietMinCame = 3;
const int kGoneQuietWeeks = 6;
const int kNewcomerWeeks = 4;
const int kOneTimeWeeks = 8;
const int kTimeRuleMinMisses = 2;
const int kHistorySlots = 8;

enum CheckOnTone { strong, soft }

/// The rules, most serious first. When several match, the earliest wins.
enum CheckOnFlag {
  notComingRecently('Not coming recently', CheckOnTone.strong),
  suddenDrop('Sudden drop', CheckOnTone.strong),
  goneQuiet('Gone quiet', CheckOnTone.soft),
  newcomerFollowUp('Newcomer follow-up', CheckOnTone.soft),
  oneTimeVisitor('One-time visitor', CheckOnTone.soft);

  const CheckOnFlag(this.label, this.tone);

  final String label;
  final CheckOnTone tone;
}

/// One of the last eight meetings in a person's history dots.
enum CheckOnSlot {
  came,

  /// A miss that triggered the flag.
  missedLately,

  /// Any other miss after the person's first appearance.
  missedEarlier,

  /// Before the person's first appearance, or before the event had met
  /// eight times.
  noMeetingYet,
}

/// One flagged person on one event.
class CheckOnEntry {
  const CheckOnEntry({
    required this.eventId,
    required this.eventTitle,
    required this.memberId,
    required this.displayName,
    required this.flag,
    required this.reason,
    required this.lastPresent,
    required this.history,
  });

  final String eventId;
  final String eventTitle;
  final String memberId;
  final String displayName;
  final CheckOnFlag flag;

  /// Plain one-line reason, e.g. "Missed the last 3 · last here Oct 23".
  final String reason;

  final DateTime lastPresent;

  /// The last [kHistorySlots] meetings, oldest first.
  final List<CheckOnSlot> history;

  CheckOnTone get tone => flag.tone;
}

/// One person across events, with a line per event they are flagged on.
class CheckOnPerson {
  CheckOnPerson(this.entries);

  /// Most serious first; never empty.
  final List<CheckOnEntry> entries;

  String get memberId => entries.first.memberId;
  String get displayName => entries.first.displayName;
  CheckOnFlag get flag => entries.first.flag;
  CheckOnTone get tone => flag.tone;
}

/// Who to check on for one event, most serious first.
///
/// [members] may be the whole member list: only the event's live roster is
/// considered, each member once. Sessions of other events and deleted
/// sessions are ignored.
List<CheckOnEntry> checkOnForEvent({
  required Event event,
  required List<Member> members,
  required List<Session> sessions,
}) {
  final eventSessions = _sessionsFor(event, sessions);
  if (eventSessions.length < kCheckOnMinSessions) return const [];
  final latest = eventSessions.last.sessionDate;

  final roster = _rosterFor(event, members);
  final nameCounts = <String, int>{};
  for (final m in roster) {
    nameCounts[m.displayName] = (nameCounts[m.displayName] ?? 0) + 1;
  }

  final out = <CheckOnEntry>[];
  for (final m in roster) {
    final meetings = <Session>[];
    final came = <bool>[];
    final matchByName = nameCounts[m.displayName] == 1;
    for (final s in eventSessions) {
      if (s.excludedMemberIds.contains(m.id)) continue;
      meetings.add(s);
      came.add(_cameTo(s, m, matchByName));
    }
    final entry = _evaluate(event, m, meetings, came, latest);
    if (entry != null) out.add(entry);
  }
  out.sort(_compare);
  return out;
}

/// Groups per-event results by person, most serious person first.
List<CheckOnPerson> groupByPerson(Iterable<CheckOnEntry> entries) {
  final byMember = <String, List<CheckOnEntry>>{};
  for (final e in entries) {
    byMember.putIfAbsent(e.memberId, () => []).add(e);
  }
  final people = [
    for (final list in byMember.values) CheckOnPerson(list..sort(_compare)),
  ];
  people.sort((a, b) => _compare(a.entries.first, b.entries.first));
  return people;
}

/// Most serious flag, then away longest, then name, then event.
int _compare(CheckOnEntry a, CheckOnEntry b) {
  var c = a.flag.index.compareTo(b.flag.index);
  if (c != 0) return c;
  c = a.lastPresent.compareTo(b.lastPresent);
  if (c != 0) return c;
  c = a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  if (c != 0) return c;
  return a.eventTitle.compareTo(b.eventTitle);
}

CheckOnEntry? _evaluate(
  Event event,
  Member member,
  List<Session> meetings,
  List<bool> came,
  DateTime latest,
) {
  final total = came.where((c) => c).length;
  if (total == 0) return null;
  final firstIdx = came.indexOf(true);
  final lastIdx = came.lastIndexOf(true);
  final lastPresent = meetings[lastIdx].sessionDate;
  final trailingMisses = came.length - 1 - lastIdx;
  final daysAway = _daysBetween(lastPresent, latest);
  final trailing = {for (var i = lastIdx + 1; i < came.length; i++) i};
  final lastHere = 'last here ${_date(lastPresent)}';

  CheckOnEntry entry(CheckOnFlag flag, String reason, Set<int> lately) {
    final history = <CheckOnSlot>[
      for (var i = came.length - kHistorySlots; i < came.length; i++)
        if (i < firstIdx)
          CheckOnSlot.noMeetingYet
        else if (came[i])
          CheckOnSlot.came
        else if (lately.contains(i))
          CheckOnSlot.missedLately
        else
          CheckOnSlot.missedEarlier,
    ];
    return CheckOnEntry(
      eventId: event.id,
      eventTitle: event.title,
      memberId: member.id,
      displayName: member.displayName,
      flag: flag,
      reason: reason,
      lastPresent: lastPresent,
      history: history,
    );
  }

  if (total >= kNotComingMinCame && trailingMisses >= kNotComingMisses) {
    return entry(
      CheckOnFlag.notComingRecently,
      'Missed the last $trailingMisses · $lastHere',
      trailing,
    );
  }

  if (came.length >= kDropPriorMeetings + kDropRecentMeetings) {
    final recentStart = came.length - kDropRecentMeetings;
    final priorCame = came
        .sublist(recentStart - kDropPriorMeetings, recentStart)
        .where((c) => c)
        .length;
    final recentMissed = {
      for (var i = recentStart; i < came.length; i++)
        if (!came[i]) i,
    };
    if (priorCame / kDropPriorMeetings >= kDropPriorRate &&
        recentMissed.length >= kDropRecentMisses) {
      return entry(
        CheckOnFlag.suddenDrop,
        'Missed ${recentMissed.length} of the last $kDropRecentMeetings'
        ' · $lastHere',
        recentMissed,
      );
    }
  }

  final awayLongEnough = trailingMisses >= kTimeRuleMinMisses;

  if (total >= kGoneQuietMinCame &&
      awayLongEnough &&
      daysAway >= kGoneQuietWeeks * 7) {
    return entry(
      CheckOnFlag.goneQuiet,
      'Not seen for ${daysAway ~/ 7} weeks · $lastHere',
      trailing,
    );
  }

  if (total == 1 &&
      _daysBetween(meetings[firstIdx].sessionDate, latest) <
          kNewcomerWeeks * 7) {
    return entry(
      CheckOnFlag.newcomerFollowUp,
      'First time on ${_date(lastPresent)}',
      const {},
    );
  }

  if (total == 1 && awayLongEnough && daysAway >= kOneTimeWeeks * 7) {
    return entry(
      CheckOnFlag.oneTimeVisitor,
      'Came once · ${_date(lastPresent)}',
      trailing,
    );
  }

  return null;
}

/// Whether [member] has a present mark in [session]. A mark with no member
/// id counts when its name matches a member whose name is unique on the
/// roster: marks from before events carried ids are still that person.
bool _cameTo(Session session, Member member, bool matchByName) {
  for (final r in session.records) {
    if (r.status != AttendanceStatus.present) continue;
    final mid = r.memberId;
    if (mid != null && mid.trim().isNotEmpty) {
      if (mid == member.id) return true;
    } else if (matchByName && r.attendee == member.displayName) {
      return true;
    }
  }
  return false;
}

/// Live roster members, one per id. An empty roster on the event means
/// everyone, as for marking.
List<Member> _rosterFor(Event event, List<Member> members) {
  final seen = <String>{};
  final active = members.where((m) => m.deletedAt == null && seen.add(m.id));
  if (event.memberIds.isEmpty) return active.toList();
  final ids = event.memberIds.toSet();
  return active.where((m) => ids.contains(m.id)).toList();
}

/// Live sessions of this event, oldest first. Sessions recorded before events
/// carried an id match by title, as in the history list.
List<Session> _sessionsFor(Event event, List<Session> sessions) {
  final title = event.title.trim();
  return sessions.where((s) {
    if (s.deletedAt != null) return false;
    final id = s.eventId;
    if (id != null && id.isNotEmpty) return id == event.id;
    return s.title.trim() == title;
  }).toList()
    ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
}

/// Whole calendar days from [from] to [to], ignoring time of day and DST.
int _daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

String _date(DateTime d) => DateFormat('MMM d').format(d);
