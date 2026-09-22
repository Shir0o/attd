import '../../../../data/session.dart';
import '../../../../data/session_record.dart';
import '../../attendance/models/attendance_status.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';
import '../../hub/domain/event.dart';
import 'insights_config.dart';

export 'insights_config.dart';

/// One recorded session, reduced to the numbers every section reads from.
class SessionPoint {
  SessionPoint({
    required this.session,
    required this.present,
    required this.total,
    required this.lateCount,
    required this.guestCount,
    required this.cumulativePeopleSeen,
  });

  final Session session;

  /// Roster members marked present. A late mark is a full present.
  final int present;

  /// Roster members expected. Guests are never in this number: a Guest Mark is
  /// only ever created for someone marked present and can never resolve to
  /// absent, so counting them could only push the rate up (ADR 0006).
  final int total;

  final int lateCount;
  final int guestCount;

  /// Distinct people seen at this event up to and including this session.
  final int cumulativePeopleSeen;

  DateTime get date => session.sessionDate;

  double get rate => total == 0 ? 0 : present / total;

  int get ratePercent => (rate * 100).round();

  int get absent => total - present;
}

/// A roster member's attendance across the range.
class MemberAttendance {
  MemberAttendance({
    required this.member,
    required this.familyName,
    required this.attended,
    required this.eligible,
    required this.currentStreak,
    required this.recentHits,
  });

  final Member member;
  final String? familyName;

  /// Sessions attended out of those the member was eligible for (a session
  /// that excluded them counts for neither).
  final int attended;
  final int eligible;

  /// Consecutive attendances counting back from the most recent session.
  final int currentStreak;

  /// Present/absent per session over the regulars window, oldest first.
  /// `null` where the session excluded this member — an exclusion is neither
  /// an attendance nor an absence, so it must not count against them.
  final List<bool?> recentHits;

  /// Sessions in the window this member was actually eligible for.
  int get recentEligible => recentHits.whereType<bool>().length;

  /// Attendances within the window.
  int get recentAttended => recentHits.where((h) => h == true).length;

  double get rate => eligible == 0 ? 0 : attended / eligible;

  int get ratePercent => (rate * 100).round();
}

/// A member who qualified as a Regular and has since stopped coming.
class LapsedAttendee {
  LapsedAttendee({
    required this.member,
    required this.familyName,
    required this.consecutiveMisses,
    required this.priorAttended,
    required this.priorEligible,
    required this.lastSeen,
  });

  final Member member;
  final String? familyName;
  final int consecutiveMisses;
  final int priorAttended;
  final int priorEligible;
  final DateTime? lastSeen;
}

/// Someone whose first mark at this event falls inside the range.
class FirstTimer {
  FirstTimer(
      {required this.name, required this.firstSeen, required this.isGuest});

  final String name;
  final DateTime firstSeen;
  final bool isGuest;
}

/// Every Insights number for one event, computed once.
///
/// Sections are pure renders of this object and never derive anything
/// themselves — that is what kept the old Trends and Regulars screens from
/// agreeing about who counts.
class EventInsights {
  EventInsights._({
    required this.event,
    required this.config,
    required this.points,
    required this.memberTable,
    required this.lapsed,
    required this.firstTimers,
    required this.guestMarkCount,
    required this.presentMarkCount,
    required this.lateMarkCount,
    required this.totalSessionsForEvent,
    required Map<String, DateTime> firstSeen,
  }) : _firstSeen = firstSeen;

  final Event event;
  final InsightsConfig config;

  /// In-range sessions, oldest first.
  final List<SessionPoint> points;

  /// Every roster member, best rate first then by name.
  final List<MemberAttendance> memberTable;

  final List<LapsedAttendee> lapsed;
  final List<FirstTimer> firstTimers;

  /// Guest marks in range. Counted here, never in [averageRatePercent].
  final int guestMarkCount;

  /// Present marks in range, roster and guests alike — the denominator of
  /// [lateRatePercent].
  final int presentMarkCount;
  final int lateMarkCount;

  /// Non-deleted sessions for this event, ignoring the range. Drives the
  /// "needs N more sessions" copy.
  final int totalSessionsForEvent;

  final Map<String, DateTime> _firstSeen;

  static EventInsights from({
    required Event event,
    required List<Session> sessions,
    required List<Member> members,
    List<Family> families = const [],
  }) {
    final cfg = event.resolvedInsightsConfig;

    final roster = _rosterFor(event, members);
    final rosterById = {for (final m in roster) m.id: m};
    final rosterByName = {for (final m in roster) m.displayName: m};
    final rosterNames = rosterByName.keys.toSet();

    final familyByMember = <String, String>{};
    for (final f in families) {
      for (final m in f.members) {
        familyByMember[m.id] = f.displayName;
      }
    }

    final relevant = _sessionsFor(event, sessions);

    // First seen spans the event's whole history, not the range: someone who
    // has attended for a year is not a first timer because the window moved.
    final firstSeen = <String, DateTime>{};
    for (final s in relevant) {
      for (final r in s.records) {
        if (r.status != AttendanceStatus.present) continue;
        final key = _identityOf(r, rosterByName);
        if (key == null) continue;
        final existing = firstSeen[key];
        if (existing == null || s.sessionDate.isBefore(existing)) {
          firstSeen[key] = s.sessionDate;
        }
      }
    }

    final inRange = relevant.length <= cfg.resolvedRange.sessionCount
        ? relevant
        : relevant.sublist(relevant.length - cfg.resolvedRange.sessionCount);

    // One pass builds the per-session points and the per-member tallies.
    final attended = <String, int>{};
    final eligible = <String, int>{};
    final attendanceByMember = <String, List<bool?>>{};
    var guestMarks = 0;
    var presentMarks = 0;
    var lateMarks = 0;
    final seenSoFar = <String>{};
    final pts = <SessionPoint>[];

    for (final s in inRange) {
      final byId = <String, SessionRecord>{};
      final byName = <String, SessionRecord>{};
      for (final r in s.records) {
        final mid = r.memberId;
        if (mid != null && mid.trim().isNotEmpty) {
          byId[mid] = r;
        } else {
          byName[r.attendee] = r;
        }
      }

      final excluded = s.excludedMemberIds.toSet();
      var present = 0;
      var total = 0;
      var late = 0;

      for (final m in roster) {
        final list = attendanceByMember.putIfAbsent(m.id, () => <bool?>[]);
        if (excluded.contains(m.id)) {
          list.add(null);
          continue;
        }
        total++;
        eligible[m.id] = (eligible[m.id] ?? 0) + 1;
        final record = byId[m.id] ?? byName[m.displayName];
        final isPresent = record?.status == AttendanceStatus.present;
        if (isPresent) {
          present++;
          attended[m.id] = (attended[m.id] ?? 0) + 1;
          if (record!.isLate) late++;
        }
        list.add(isPresent);
      }

      var guests = 0;
      for (final r in s.records) {
        if (r.status != AttendanceStatus.present) continue;
        presentMarks++;
        if (r.isLate) lateMarks++;
        if (_isGuestMark(r, rosterNames)) {
          guests++;
          guestMarks++;
        }
        final key = _identityOf(r, rosterByName);
        if (key != null) seenSoFar.add(key);
      }

      pts.add(
        SessionPoint(
          session: s,
          present: present,
          total: total,
          lateCount: late,
          guestCount: guests,
          cumulativePeopleSeen: seenSoFar.length,
        ),
      );
    }

    final window = cfg.resolvedRegularWindow;
    final table = <MemberAttendance>[];
    for (final m in roster) {
      final history = attendanceByMember[m.id] ?? const <bool?>[];
      final recent = history.length <= window
          ? history
          : history.sublist(history.length - window);

      var streak = 0;
      for (var i = history.length - 1; i >= 0; i--) {
        final v = history[i];
        if (v == null) continue;
        if (v) {
          streak++;
        } else {
          break;
        }
      }

      table.add(
        MemberAttendance(
          member: m,
          familyName: familyByMember[m.id],
          attended: attended[m.id] ?? 0,
          eligible: eligible[m.id] ?? 0,
          currentStreak: streak,
          recentHits: List<bool?>.from(recent),
        ),
      );
    }
    table.sort((a, b) {
      final byRate = b.rate.compareTo(a.rate);
      if (byRate != 0) return byRate;
      return a.member.displayName.toLowerCase().compareTo(
            b.member.displayName.toLowerCase(),
          );
    });

    final lapsedList = _lapsed(
      roster: roster,
      attendanceByMember: attendanceByMember,
      inRange: inRange,
      familyByMember: familyByMember,
      cfg: cfg,
    );

    final rangeStart = inRange.isEmpty ? null : inRange.first.sessionDate;
    final firstTimers = <FirstTimer>[];
    if (rangeStart != null) {
      firstSeen.forEach((key, date) {
        if (date.isBefore(rangeStart)) return;
        final member = rosterById[key];
        firstTimers.add(
          FirstTimer(
            name: member?.displayName ?? key,
            firstSeen: date,
            isGuest: member == null,
          ),
        );
      });
      firstTimers.sort((a, b) => b.firstSeen.compareTo(a.firstSeen));
    }

    return EventInsights._(
      event: event,
      config: cfg,
      points: pts,
      memberTable: table,
      lapsed: lapsedList,
      firstTimers: firstTimers,
      guestMarkCount: guestMarks,
      presentMarkCount: presentMarks,
      lateMarkCount: lateMarks,
      totalSessionsForEvent: relevant.length,
      firstSeen: firstSeen,
    );
  }

  // ── Session and roster scoping ──────────────────────────────────────────

  static List<Member> _rosterFor(Event event, List<Member> members) {
    final active = members.where((m) => m.deletedAt == null);
    if (event.memberIds.isEmpty) return active.toList();
    final ids = event.memberIds.toSet();
    return active.where((m) => ids.contains(m.id)).toList();
  }

  /// Sessions of this event, oldest first.
  ///
  /// Matches by event id, falling back to the title for sessions recorded
  /// before events carried one — the same rule the history list applies, so
  /// Insights does not silently start partway through your history.
  static List<Session> _sessionsFor(Event event, List<Session> sessions) {
    final title = event.title.trim();
    final relevant = sessions.where((s) {
      if (s.deletedAt != null) return false;
      final id = s.eventId;
      if (id != null && id.isNotEmpty) return id == event.id;
      return s.title.trim() == title;
    }).toList()
      ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    return relevant;
  }

  /// A record with no member link whose name matches nobody on the roster.
  static bool _isGuestMark(SessionRecord r, Set<String> rosterNames) {
    final mid = r.memberId;
    if (mid != null && mid.trim().isNotEmpty) return false;
    return !rosterNames.contains(r.attendee);
  }

  /// A stable key for "who this mark is about".
  ///
  /// The member id when the mark carries one; otherwise the id of the roster
  /// member whose name it matches, so a mark recorded before events carried
  /// identifiers is still that person rather than a stranger; only a name
  /// matching nobody keys by itself.
  static String? _identityOf(
      SessionRecord r, Map<String, Member> rosterByName) {
    final mid = r.memberId;
    if (mid != null && mid.trim().isNotEmpty) return mid;
    if (r.attendee.trim().isEmpty) return null;
    return rosterByName[r.attendee]?.id ?? r.attendee;
  }

  static List<LapsedAttendee> _lapsed({
    required List<Member> roster,
    required Map<String, List<bool?>> attendanceByMember,
    required List<Session> inRange,
    required Map<String, String> familyByMember,
    required InsightsConfig cfg,
  }) {
    final misses = cfg.resolvedLapsedConsecutiveMisses;
    final minPrior = cfg.resolvedLapsedMinimumPriorSessions;
    final threshold = cfg.resolvedRegularThresholdPercent / 100;
    final out = <LapsedAttendee>[];

    for (final m in roster) {
      final history = attendanceByMember[m.id] ?? const <bool?>[];
      final marked = <int>[];
      for (var i = 0; i < history.length; i++) {
        if (history[i] != null) marked.add(i);
      }
      if (marked.length < minPrior + misses) continue;

      // The trailing run of absences must be exactly long enough.
      var run = 0;
      for (var i = marked.length - 1; i >= 0; i--) {
        if (history[marked[i]] == false) {
          run++;
        } else {
          break;
        }
      }
      if (run < misses) continue;

      final priorIndices = marked.sublist(0, marked.length - run);
      if (priorIndices.length < minPrior) continue;
      final priorAttended =
          priorIndices.where((i) => history[i] == true).length;
      if (priorAttended / priorIndices.length < threshold) continue;

      DateTime? lastSeen;
      for (var i = priorIndices.length - 1; i >= 0; i--) {
        if (history[priorIndices[i]] == true) {
          lastSeen = inRange[priorIndices[i]].sessionDate;
          break;
        }
      }

      out.add(
        LapsedAttendee(
          member: m,
          familyName: familyByMember[m.id],
          consecutiveMisses: run,
          priorAttended: priorAttended,
          priorEligible: priorIndices.length,
          lastSeen: lastSeen,
        ),
      );
    }

    out.sort((a, b) => b.consecutiveMisses.compareTo(a.consecutiveMisses));
    return out;
  }

  // ── Headline figures ────────────────────────────────────────────────────

  bool get hasSessions => points.isNotEmpty;

  int? get averageRatePercent {
    if (points.isEmpty) return null;
    final sum = points.fold<double>(0, (acc, p) => acc + p.rate);
    return (sum / points.length * 100).round();
  }

  /// The earlier half of the range, for the up/down comparison.
  int? get priorAverageRatePercent {
    if (points.isEmpty) return null;
    final half = points.length ~/ 2;
    if (half == 0) return averageRatePercent;
    final sum = points.take(half).fold<double>(0, (acc, p) => acc + p.rate);
    return (sum / half * 100).round();
  }

  bool get isImproving =>
      (averageRatePercent ?? 0) >= (priorAverageRatePercent ?? 0);

  SessionPoint? get bestSession {
    if (points.isEmpty) return null;
    return points.reduce((a, b) => a.rate >= b.rate ? a : b);
  }

  SessionPoint? get lowestSession {
    if (points.isEmpty) return null;
    return points.reduce((a, b) => a.rate <= b.rate ? a : b);
  }

  /// The median number of people in the room, guests included: ADR 0006
  /// scopes the guest exclusion to rates, and a headcount is not a rate.
  int? get medianPresentCount {
    if (points.isEmpty) return null;
    final counts = points.map((p) => p.present + p.guestCount).toList()..sort();
    final mid = counts.length ~/ 2;
    if (counts.length.isOdd) return counts[mid];
    return ((counts[mid - 1] + counts[mid]) / 2).round();
  }

  int get rosterSize => memberTable.length;

  /// Present marks that carried the late flag, over all present marks. Never
  /// moves the attendance rate — lateness is reported, not deducted.
  int? get lateRatePercent {
    if (presentMarkCount == 0) return null;
    return (lateMarkCount / presentMarkCount * 100).round();
  }

  List<MemberAttendance> get regulars {
    if (sessionsNeededFor(InsightsSection.regulars) > 0) return const [];
    final threshold = config.resolvedRegularThresholdPercent / 100;
    final window = config.resolvedRegularWindow;
    return memberTable.where((m) {
      if (m.recentHits.length < window) return false;
      if (m.recentEligible == 0) return false;
      return m.recentAttended / m.recentEligible >= threshold;
    }).toList();
  }

  MemberAttendance? get longestCurrentStreak {
    if (memberTable.isEmpty) return null;
    final ranked = [...memberTable]
      ..sort((a, b) => b.currentStreak.compareTo(a.currentStreak));
    final best = ranked.first;
    return best.currentStreak == 0 ? null : best;
  }

  DateTime? firstSeenFor(String memberIdOrName) => _firstSeen[memberIdOrName];

  /// How many more sessions a section needs before it can say anything honest.
  ///
  /// Zero means it is ready. A section short of this renders a placeholder
  /// rather than hiding (which reads as a bug) or showing a partial figure
  /// (which reads as a fact).
  int sessionsNeededFor(InsightsSection section) {
    switch (section) {
      case InsightsSection.regulars:
        return _shortfall(config.resolvedRegularWindow);
      case InsightsSection.lapsed:
        return _shortfall(
          config.resolvedLapsedMinimumPriorSessions +
              config.resolvedLapsedConsecutiveMisses,
        );
      case InsightsSection.rateOverTime:
      case InsightsSection.growth:
        return _shortfall(2);
      case InsightsSection.extremes:
      case InsightsSection.guests:
      case InsightsSection.lateness:
      case InsightsSection.memberTable:
      case InsightsSection.firstTimers:
      case InsightsSection.streaks:
      case InsightsSection.medianSize:
        return _shortfall(1);
    }
  }

  int _shortfall(int needed) {
    final have = totalSessionsForEvent;
    return have >= needed ? 0 : needed - have;
  }

  /// Whether a section belongs on the page at all.
  ///
  /// Guests and lateness are default-on but suppress themselves at zero, so an
  /// event with neither pays nothing for them.
  bool isVisible(InsightsSection section) {
    if (!config.resolvedVisibleSections.contains(section)) return false;
    switch (section) {
      case InsightsSection.guests:
        return guestMarkCount > 0;
      case InsightsSection.lateness:
        return lateMarkCount > 0;
      default:
        return true;
    }
  }

  /// Sections to render, in page order.
  List<InsightsSection> get visibleSections =>
      InsightsSection.values.where(isVisible).toList();
}
