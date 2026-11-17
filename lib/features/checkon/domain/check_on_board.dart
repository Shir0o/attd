/// Who to check on across events, after the owner's ticks and "stop flagging"
/// choices.
///
/// The rules (`check_on.dart`) are pure and know nothing of the owner's
/// answers. This layer applies them: the answers live on each [Event]
/// (`checkOnFollowUps`, `checkOnStopFlagging`) so they travel with it through
/// backup, restore and merge.
library;

import '../../../data/session.dart';
import '../../attendance/models/member.dart';
import '../../hub/domain/event.dart';
import 'check_on.dart';
import 'check_on_follow_up.dart';

class CheckOnBoard {
  CheckOnBoard._(this.entries, this._followedUp);

  /// Every flagged person-event not stopped, most serious first, including
  /// the ones already followed up on.
  final List<CheckOnEntry> entries;
  final Set<CheckOnEntry> _followedUp;

  /// Computes the board for the live [events]. Deleted events are skipped, and
  /// so are events handed off by someone else: their roster is not this
  /// phone's to follow up on.
  factory CheckOnBoard.compute({
    required Iterable<Event> events,
    required List<Member> members,
    required List<Session> sessions,
  }) {
    final entries = <CheckOnEntry>[];
    final followedUp = <CheckOnEntry>{};
    for (final event in events) {
      if (event.deletedAt != null || event.isHandedOff) continue;
      for (final entry in checkOnForEvent(
        event: event,
        members: members,
        sessions: sessions,
      )) {
        if (event.checkOnStopFlagging.contains(entry.memberId)) continue;
        entries.add(entry);
        if (event.followUpAnswers(entry)) followedUp.add(entry);
      }
    }
    return CheckOnBoard._(entries, followedUp);
  }

  /// Whether the owner already followed up on exactly this flag.
  bool isFollowedUp(CheckOnEntry entry) => _followedUp.contains(entry);

  /// People still to check on, most serious first. A person appears with only
  /// the lines not yet followed up on. This is what the hub card, the summary
  /// line and their counts use.
  List<CheckOnPerson> get toCheck =>
      groupByPerson(entries.where((e) => !isFollowedUp(e)));

  /// Everyone flagged, for the report: people still to check on first, then
  /// the ones whose every line is followed up. Each person keeps all their
  /// lines. [eventId] limits it to one event.
  List<CheckOnPerson> people({String? eventId}) {
    final scoped =
        eventId == null ? entries : entries.where((e) => e.eventId == eventId);
    final all = groupByPerson(scoped);
    return [
      ...all.where((p) => !isPersonFollowedUp(p)),
      ...all.where(isPersonFollowedUp),
    ];
  }

  /// True when every line of [person] is followed up on.
  bool isPersonFollowedUp(CheckOnPerson person) =>
      person.entries.every(isFollowedUp);
}

extension CheckOnEventState on Event {
  /// Whether a tick on this event already answers [entry]: same flag, and the
  /// person has not attended since.
  bool followUpAnswers(CheckOnEntry entry) =>
      checkOnFollowUps[entry.memberId]?.answers(
        entry.flag.name,
        entry.lastPresent,
      ) ??
      false;

  /// This event with each of [entries] (this event's own) ticked.
  Event withFollowUps(Iterable<CheckOnEntry> entries) => copyWith(
        checkOnFollowUps: {
          ...checkOnFollowUps,
          for (final e in entries)
            e.memberId: CheckOnFollowUp(
              flag: e.flag.name,
              lastPresent: e.lastPresent,
            ),
        },
      );

  /// This event with the ticks of [memberIds] removed.
  Event withoutFollowUps(Iterable<String> memberIds) => copyWith(
        checkOnFollowUps: {
          for (final e in checkOnFollowUps.entries)
            if (!memberIds.contains(e.key)) e.key: e.value,
        },
      );

  Event withStopFlagging(String memberId) =>
      copyWith(checkOnStopFlagging: {...checkOnStopFlagging, memberId});

  /// Undo of [withStopFlagging].
  Event withoutStopFlagging(String memberId) => copyWith(
        checkOnStopFlagging: {
          for (final id in checkOnStopFlagging)
            if (id != memberId) id,
        },
      );
}
