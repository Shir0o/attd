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
    required List<Session> recentSessions,
  }) {
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
    for (final m in display) {
      _rateById[m.id] = attendanceRate(m.id, recentSessions);
    }

    this.members = rankByLikelihood(display, recentSessions);
    for (var i = 0; i < this.members.length; i++) {
      likelihoodPriority[this.members[i].id] = i;
    }
  }

  /// Display members in likelihood order (most likely present first).
  late final List<Member> members;

  /// Households in the event roster, as the host resolved them.
  final List<Family> families;

  /// Member id → its index in [members], for breaking search ties.
  final Map<String, int> likelihoodPriority = {};

  final Map<String, bool> _present = {};
  final Map<String, String?> _familyNameById = {};
  final Map<String, double?> _rateById = {};

  bool isPresent(Member member) => _present[member.id] ?? false;

  /// The member's household, or `null` for a loner / auto-singleton bucket.
  String? familyNameFor(Member member) => _familyNameById[member.id];

  /// Recent attendance rate, or `null` without enough history to rank.
  double? rateFor(Member member) => _rateById[member.id];

  String subtitleFor(Member member) =>
      memberSubtitle(familyNameFor(member), rateFor(member));

  /// Members not yet marked present, in likelihood order.
  List<Member> get unmarked =>
      members.where((m) => !isPresent(m)).toList(growable: false);

  List<SearchEntry> get searchEntries => [
        for (final m in members) (member: m, familyName: familyNameFor(m)),
      ];
}
