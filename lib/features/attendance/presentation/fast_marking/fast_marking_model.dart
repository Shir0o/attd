import '../../../../data/session.dart';
import '../../domain/active_roster_index.dart';
import '../../models/attendance_status.dart';
import '../../models/member.dart';
import '../../utils/session_roster_utils.dart';

typedef MemberMarkCallback = Future<void> Function(
    Member member, bool isPresent);

/// Everything the name grid needs to *read* about a session, derived once by
/// the host so the grid stays presentation-only.
class FastMarkingRoster {
  FastMarkingRoster({
    required Session session,
    required List<Member> members,
    ActiveRosterIndex? index,
  }) : index = index ?? ActiveRosterIndex(members: members) {
    final roster = SessionRoster(session, members);
    final display = roster.displayMembersMap.values.toList();

    for (final m in display) {
      _present[m.id] = roster.getStatus(m) == AttendanceStatus.present;
    }

    alphabetical = List.unmodifiable(
      display
        ..sort((a, b) {
          final byName =
              a.displayNameLowercase.compareTo(b.displayNameLowercase);
          if (byName != 0) return byName;
          return SessionRoster.keyFor(a).compareTo(SessionRoster.keyFor(b));
        }),
    );
  }

  /// The people on the session, A to Z by display name ignoring case, for the
  /// name grid. Guests and visitors on the session sort in with everyone.
  late final List<Member> alphabetical;

  /// The active roster index backing name display (given name and surname).
  final ActiveRosterIndex index;

  final Map<String, bool> _present = {};

  bool isPresent(Member member) => _present[member.id] ?? false;

  /// Members not yet marked present, in grid order.
  List<Member> get unmarked =>
      alphabetical.where((m) => !isPresent(m)).toList(growable: false);
}
