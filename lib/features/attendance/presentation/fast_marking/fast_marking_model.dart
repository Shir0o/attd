import '../../../../data/session.dart';
import '../../models/attendance_status.dart';
import '../../models/family.dart';
import '../../models/member.dart';
import '../../utils/member_default_resolver.dart';
import '../../utils/session_roster_utils.dart';
import 'fast_marking_shared.dart';

typedef MemberMarkCallback = Future<void> Function(
    Member member, bool isPresent);
typedef FamilyMarkCallback = Future<void> Function(
    Family family, bool isPresent);

/// How likely each member is to be here, derived from session history.
///
/// Split out from [FastMarkingRoster] because it is the expensive half and
/// depends only on the roster and the history, never on the marks made so far.
/// The host holds one and reuses it: recomputing an attendance rate per member
/// per keystroke is far too much work on the large rosters this exists for.
class MarkingLikelihood {
  MarkingLikelihood(List<Member> members, List<Session> recentSessions)
    : rates = {
        for (final m in members) m.id: attendanceRate(m.id, recentSessions),
      } {
    final ranked = rankByLikelihood(members, recentSessions);
    for (var i = 0; i < ranked.length; i++) {
      order[ranked[i].id] = i;
    }
  }

  /// Member id → recent attendance rate, or null without enough history.
  final Map<String, double?> rates;

  /// Member id → its place in the likelihood order (most likely first).
  final Map<String, int> order = {};
}

/// Everything the fast marking surfaces need to *read* about a session,
/// derived once by the host so each surface stays presentation-only.
///
/// Members are exposed in likelihood order — most likely to be in the room
/// first — because every surface either shows them that way (the grid) or uses
/// it to break search ties.
class FastMarkingRoster {
  FastMarkingRoster({
    required Session session,
    required List<Member> members,
    required this.families,
    required MarkingLikelihood likelihood,
  }) : likelihoodPriority = likelihood.order,
       _rateById = likelihood.rates {
    final roster = SessionRoster(session, members);
    final display = roster.displayMembersMap.values.toList();

    for (final m in display) {
      _present[m.id] = roster.getStatus(m) == AttendanceStatus.present;
    }
    for (final f in families) {
      for (final m in f.members) {
        _familyNameById[m.id] = f.isAutoSingleton ? null : f.displayName;
      }
    }

    // Display members carry the name captured on the record, so they are
    // re-derived every build; the likelihood order they sort by is not.
    const unranked = 1 << 30;
    this.members = display
      ..sort((a, b) {
        final byOrder = (likelihoodPriority[a.id] ?? unranked).compareTo(
          likelihoodPriority[b.id] ?? unranked,
        );
        if (byOrder != 0) return byOrder;
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      });
  }

  /// Display members in likelihood order (most likely present first).
  late final List<Member> members;

  /// Households in the event roster, as the host resolved them.
  final List<Family> families;

  /// Member id → its index in [members], for breaking search ties.
  final Map<String, int> likelihoodPriority;

  final Map<String, bool> _present = {};
  final Map<String, String?> _familyNameById = {};
  final Map<String, double?> _rateById;

  bool isPresent(Member member) => _present[member.id] ?? false;

  /// The member's household, or `null` for a loner / auto-singleton bucket.
  String? familyNameFor(Member member) => _familyNameById[member.id];

  /// Recent attendance rate, or `null` without enough history to rank.
  double? rateFor(Member member) => _rateById[member.id];

  String subtitleFor(Member member) =>
      memberSubtitle(familyNameFor(member), rateFor(member));

  /// How many of [family] are currently marked present.
  int presentCountIn(Family family) =>
      family.members.where(isPresent).length;

  /// How many of [family] usually turn up, from their recent attendance.
  int usualCountIn(Family family) => family.members
      .where((m) => (rateFor(m) ?? 0) >= 0.5)
      .length;

  /// Members not yet marked present, in likelihood order.
  List<Member> get unmarked =>
      members.where((m) => !isPresent(m)).toList(growable: false);

  List<SearchEntry> get searchEntries => [
        for (final m in members) (member: m, familyName: familyNameFor(m)),
      ];
}
