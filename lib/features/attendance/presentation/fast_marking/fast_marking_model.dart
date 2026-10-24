import '../../../../data/session.dart';
import '../../domain/active_roster_index.dart';
import '../../models/attendance_status.dart';
import '../../models/family.dart';
import '../../models/member.dart';
import '../../utils/session_roster_utils.dart';

typedef MemberMarkCallback = Future<void> Function(
    Member member, bool isPresent);
typedef FamilyMarkCallback = Future<void> Function(
    Family family, bool isPresent);

/// Compatibility bridge for [MarkingLikelihood] backed by [ActiveRosterIndex].
class MarkingLikelihood {
  MarkingLikelihood(List<Member> members, List<Session> recentSessions)
      : this.fromIndex(
          ActiveRosterIndex(members: members, recentSessions: recentSessions),
        );

  MarkingLikelihood.fromIndex(ActiveRosterIndex index)
      : rates = {
          for (final m in index.likelyHere()) m.id: index.rateFor(m),
        },
        order = index.likelihoodPriority;

  /// Member id → recent attendance rate, or null without enough history.
  final Map<String, double?> rates;

  /// Member id → its place in the likelihood order (most likely first).
  final Map<String, int> order;
}

/// Everything the fast marking surfaces need to *read* about a session,
/// derived once by the host so each surface stays presentation-only.
///
/// Members are exposed in likelihood order — most likely to be in the room
/// first — backed by [ActiveRosterIndex].
class FastMarkingRoster {
  FastMarkingRoster({
    required Session session,
    required List<Member> members,
    required this.families,
    ActiveRosterIndex? index,
    MarkingLikelihood? likelihood,
  })  : index = index ??
            ActiveRosterIndex(
              members: members,
              families: families,
              recentSessions: const [],
            ),
        likelihoodPriority = index?.likelihoodPriority ??
            likelihood?.order ??
            const {} {
    final roster = SessionRoster(session, members);
    final display = roster.displayMembersMap.values.toList();

    for (final m in display) {
      _present[m.id] = roster.getStatus(m) == AttendanceStatus.present;
    }

    const unranked = 1 << 30;
    this.members = display
      ..sort((a, b) {
        final byOrder = (likelihoodPriority[a.id] ?? unranked).compareTo(
          likelihoodPriority[b.id] ?? unranked,
        );
        if (byOrder != 0) return byOrder;
        return a.displayNameLowercase.compareTo(b.displayNameLowercase);
      });
  }

  /// The active roster index backing query and search structures.
  final ActiveRosterIndex index;

  /// Display members in likelihood order (most likely present first).
  late final List<Member> members;

  /// Households in the event roster, as the host resolved them.
  final List<Family> families;

  /// Member id → its index in [members], for breaking search ties.
  final Map<String, int> likelihoodPriority;

  final Map<String, bool> _present = {};

  bool isPresent(Member member) => _present[member.id] ?? false;

  /// The member's household, or `null` for a loner / auto-singleton bucket.
  String? familyNameFor(Member member) => index.familyNameFor(member);

  /// Recent attendance rate, or `null` without enough history to rank.
  double? rateFor(Member member) => index.rateFor(member);

  String subtitleFor(Member member) => index.subtitleFor(member);

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

  /// Built from [members], not the index's base roster: the display list is
  /// deduped by id (a member under two households arrives twice) and carries
  /// the guests and visitors recorded on this session.
  List<SearchEntry> get searchEntries => [
        for (final m in members) (member: m, familyName: familyNameFor(m)),
      ];

  /// The [members] matching [query], best match first, capped at [limit].
  List<SearchEntry> search(String query, {int? limit}) {
    final results = ActiveRosterIndex.executeRankedSearch(
      searchEntries,
      query,
      priority: likelihoodPriority,
    );
    return limit != null && results.length > limit
        ? results.sublist(0, limit)
        : results;
  }
}

