import 'package:intl/intl.dart';

import '../../data/session.dart';
import '../../data/session_record.dart';
import '../../data/session_repository.dart';
import '../../features/attendance/data/attendance_repository.dart';
import '../../features/attendance/models/family.dart';
import '../../features/attendance/models/member.dart';
import '../logging/app_logger.dart';

final _log = AppLogger('BulkMaintenanceService');

class BulkDryRunResult {
  const BulkDryRunResult({
    required this.sessionsAffected,
    required this.marksUpdated,
    required this.collisionsPruned,
    required this.rosterMembersUpdated,
    required this.rosterMembersRemoved,
    required this.affectedSessionTitles,
  });

  final int sessionsAffected;
  final int marksUpdated;
  final int collisionsPruned;
  final int rosterMembersUpdated;
  final int rosterMembersRemoved;
  final List<String> affectedSessionTitles;

  int get totalOperations =>
      marksUpdated + collisionsPruned + rosterMembersUpdated + rosterMembersRemoved;
}

/// How a historical session was matched when repairing an event title.
enum EventTitleMatch {
  /// The session carries the event id.
  linked,

  /// The session has no event id, so it matched on its recorded title.
  titleOnly,
}

/// Sessions an event title repair would rewrite, classified by match.
class EventTitleRepairPreview {
  const EventTitleRepairPreview({required this.matches});

  final List<({String label, EventTitleMatch match})> matches;

  int get linkedCount =>
      matches.where((m) => m.match == EventTitleMatch.linked).length;

  int get titleOnlyCount =>
      matches.where((m) => m.match == EventTitleMatch.titleOnly).length;

  int get sessionsAffected => matches.length;

  List<String> get sampleLabels => matches.take(3).map((m) => m.label).toList();
}

/// One live member record that shares a display name with another record.
class DuplicateMemberOccurrence {
  const DuplicateMemberOccurrence({
    required this.member,
    required this.family,
    required this.linkedMarkCount,
  });

  final Member member;
  final Family family;
  final int linkedMarkCount;

  bool get isLoner => family.isAutoSingleton;
}

/// A group of live member records whose display names normalise to the same
/// text. Same-name records are only a suggestion: the merge itself is keyed by
/// member id, so two genuinely different people are never merged by accident.
class DuplicateMemberGroup {
  const DuplicateMemberGroup({
    required this.displayName,
    required this.occurrences,
    required this.unlinkedMarkCount,
  });

  final String displayName;
  final List<DuplicateMemberOccurrence> occurrences;

  /// Marks with no member link (legacy or guest) whose attendee text matches.
  /// They are reported for context but never rewritten by an id-based merge.
  final int unlinkedMarkCount;

  String get key => normaliseName(displayName);

  DuplicateMemberOccurrence get suggestedTarget => occurrences.first;

  static String normaliseName(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// One explicit source -> target pair for an id-based member merge.
class MemberMergePlan {
  const MemberMergePlan({
    required this.sourceMemberId,
    required this.targetMemberId,
    required this.sourceName,
    required this.targetName,
  });

  final String sourceMemberId;
  final String targetMemberId;
  final String sourceName;
  final String targetName;
}

class BulkMaintenanceService {
  BulkMaintenanceService({
    required this.attendanceRepository,
    required this.sessionRepository,
  });

  final AttendanceRepository attendanceRepository;
  final SessionRepository sessionRepository;

  Future<List<Family>> _getFamilies() => attendanceRepository.fetchAllFamilies();

  Future<List<Session>> _getSessions() => sessionRepository.fetchAllSessions();

  /// Simulates a merge of [sourceName] / [sourceIdentifier] into [targetName] / [targetMemberId].
  Future<BulkDryRunResult> simulateMerge({
    required String? sourceIdentifier,
    required String sourceName,
    required String? targetMemberId,
    required String targetName,
    required bool updateRoster,
  }) async {
    final families = await _getFamilies();
    final sessions = await _getSessions();

    int rosterMembersRemoved = 0;
    if (updateRoster && sourceIdentifier != null) {
      for (final f in families) {
        if (f.members.any((m) => m.id == sourceIdentifier && m.deletedAt == null)) {
          rosterMembersRemoved++;
        }
      }
    }

    int sessionsAffected = 0;
    int marksUpdated = 0;
    int collisionsPruned = 0;
    final affectedSessionTitles = <String>[];

    final normSourceName = sourceName.trim().toLowerCase();
    final normTargetName = targetName.trim().toLowerCase();

    for (final session in sessions) {
      bool hasTargetAlready = false;
      int sourceMatchesInSession = 0;

      for (final r in session.records) {
        final matchesSource = (sourceIdentifier != null && r.memberId == sourceIdentifier) ||
            r.attendee.trim().toLowerCase() == normSourceName;

        final matchesTarget = (targetMemberId != null && r.memberId == targetMemberId) ||
            r.attendee.trim().toLowerCase() == normTargetName;

        if (matchesSource) {
          sourceMatchesInSession++;
        }
        if (matchesTarget) {
          hasTargetAlready = true;
        }
      }

      if (sourceMatchesInSession > 0) {
        sessionsAffected++;
        marksUpdated += sourceMatchesInSession;

        if (hasTargetAlready) {
          collisionsPruned += sourceMatchesInSession;
        }

        final dateStr = DateFormat('MMM dd, yyyy').format(session.sessionDate);
        affectedSessionTitles.add('${session.title} ($dateStr)');
      }
    }

    return BulkDryRunResult(
      sessionsAffected: sessionsAffected,
      marksUpdated: marksUpdated,
      collisionsPruned: collisionsPruned,
      rosterMembersUpdated: 0,
      rosterMembersRemoved: rosterMembersRemoved,
      affectedSessionTitles: affectedSessionTitles,
    );
  }

  /// Executes the merge of [sourceName] / [sourceIdentifier] into [targetName] / [targetMemberId].
  Future<void> executeMerge({
    required String? sourceIdentifier,
    required String sourceName,
    required String? targetMemberId,
    required String targetName,
    required bool updateRoster,
  }) async {
    final families = await _getFamilies();
    final sessions = await _getSessions();
    final now = DateTime.now();

    final normSourceName = sourceName.trim().toLowerCase();
    final normTargetName = targetName.trim().toLowerCase();

    // 1. Update Roster if requested
    if (updateRoster && sourceIdentifier != null) {
      final updatedFamilies = families.map((f) {
        final remaining = f.members.where((m) => m.id != sourceIdentifier).toList();
        return f.copyWith(members: remaining, updatedAt: now);
      }).toList();

      await attendanceRepository.saveFamilies(updatedFamilies);
    }

    // 2. Update Sessions
    final updatedSessions = sessions.map((session) {
      bool sessionModified = false;
      bool targetSeen = false;

      // First pass: identify if target is already present
      for (final r in session.records) {
        final isTarget = (targetMemberId != null && r.memberId == targetMemberId) ||
            r.attendee.trim().toLowerCase() == normTargetName;
        if (isTarget) {
          targetSeen = true;
          break;
        }
      }

      final newRecords = <SessionRecord>[];
      for (final r in session.records) {
        final isSource = (sourceIdentifier != null && r.memberId == sourceIdentifier) ||
            r.attendee.trim().toLowerCase() == normSourceName;

        if (isSource) {
          sessionModified = true;
          if (targetSeen) {
            // Collision: prune the source record since target is already present in this session
            continue;
          } else {
            // Rewrite source record to target
            newRecords.add(r.copyWith(
              attendee: targetName,
              memberId: targetMemberId,
            ));
            targetSeen = true; // prevent multiple sources collapsing into multiple targets
          }
        } else {
          newRecords.add(r);
        }
      }

      if (sessionModified) {
        return session.copyWith(records: newRecords, updatedAt: now);
      }
      return session;
    }).toList();

    await sessionRepository.saveSessions(updatedSessions);

    _log.info('Bulk merge completed: "$sourceName" -> "$targetName"');
  }

  /// Simulates a bulk rename of [oldName] to [newName].
  Future<BulkDryRunResult> simulateRename({
    required String oldName,
    required String newName,
    required String? memberId,
    required bool updateRoster,
  }) async {
    final families = await _getFamilies();
    final sessions = await _getSessions();

    int rosterMembersUpdated = 0;
    if (updateRoster) {
      for (final f in families) {
        for (final m in f.members) {
          if (m.deletedAt == null &&
              ((memberId != null && m.id == memberId) ||
                  m.displayName.trim().toLowerCase() == oldName.trim().toLowerCase())) {
            rosterMembersUpdated++;
          }
        }
      }
    }

    int sessionsAffected = 0;
    int marksUpdated = 0;
    final affectedSessionTitles = <String>[];
    final normOldName = oldName.trim().toLowerCase();

    for (final session in sessions) {
      int countInSession = 0;
      for (final r in session.records) {
        final match = (memberId != null && r.memberId == memberId) ||
            r.attendee.trim().toLowerCase() == normOldName;
        if (match) countInSession++;
      }
      if (countInSession > 0) {
        sessionsAffected++;
        marksUpdated += countInSession;
        final dateStr = DateFormat('MMM dd, yyyy').format(session.sessionDate);
        affectedSessionTitles.add('${session.title} ($dateStr)');
      }
    }

    return BulkDryRunResult(
      sessionsAffected: sessionsAffected,
      marksUpdated: marksUpdated,
      collisionsPruned: 0,
      rosterMembersUpdated: rosterMembersUpdated,
      rosterMembersRemoved: 0,
      affectedSessionTitles: affectedSessionTitles,
    );
  }

  /// Executes a bulk rename of [oldName] to [newName].
  Future<void> executeRename({
    required String oldName,
    required String newName,
    required String? memberId,
    required bool updateRoster,
  }) async {
    final families = await _getFamilies();
    final sessions = await _getSessions();
    final now = DateTime.now();
    final normOldName = oldName.trim().toLowerCase();

    // 1. Update Roster
    if (updateRoster) {
      final updatedFamilies = families.map((f) {
        final updatedMembers = f.members.map((m) {
          final match = (memberId != null && m.id == memberId) ||
              m.displayName.trim().toLowerCase() == normOldName;
          if (match) {
            return m.copyWith(displayName: newName, updatedAt: now);
          }
          return m;
        }).toList();
        return f.copyWith(members: updatedMembers, updatedAt: now);
      }).toList();

      await attendanceRepository.saveFamilies(updatedFamilies);
    }

    // 2. Update Sessions
    final updatedSessions = sessions.map((session) {
      bool sessionModified = false;
      final updatedRecords = session.records.map((r) {
        final match = (memberId != null && r.memberId == memberId) ||
            r.attendee.trim().toLowerCase() == normOldName;
        if (match) {
          sessionModified = true;
          return r.copyWith(attendee: newName);
        }
        return r;
      }).toList();

      if (sessionModified) {
        return session.copyWith(records: updatedRecords, updatedAt: now);
      }
      return session;
    }).toList();

    await sessionRepository.saveSessions(updatedSessions);

    _log.info('Bulk rename completed: "$oldName" -> "$newName"');
  }

  /// Simulates rewriting the recorded title of every session that belongs to
  /// [eventId] to [newTitle], without touching the event record itself.
  ///
  /// [newTitle] may equal the event's current name: that is how history is
  /// brought in line after the event was renamed. Sessions with no event id are
  /// only matched when [legacyTitle] names the title they were recorded under.
  Future<EventTitleRepairPreview> previewEventTitleRename({
    required String eventId,
    required String newTitle,
    String? legacyTitle,
  }) async {
    _validateEventTitleRename(eventId: eventId, newTitle: newTitle);

    final sessions = await _getSessions();
    final trimmedNewTitle = newTitle.trim();
    final matches = <({String label, EventTitleMatch match})>[];

    for (final session in sessions) {
      final match = _matchEventTitle(
        session,
        eventId: eventId,
        legacyTitle: legacyTitle,
      );
      if (match == null) continue;
      if (session.title == trimmedNewTitle) continue;
      final dateStr = DateFormat('MMM dd, yyyy').format(session.sessionDate);
      matches.add((label: '${session.title} · $dateStr', match: match));
    }

    return EventTitleRepairPreview(matches: matches);
  }

  /// Rewrites the recorded title on sessions belonging to [eventId] and
  /// returns how many titles actually changed. See [previewEventTitleRename].
  Future<int> executeEventTitleRename({
    required String eventId,
    required String newTitle,
    String? legacyTitle,
  }) async {
    _validateEventTitleRename(eventId: eventId, newTitle: newTitle);

    final sessions = await _getSessions();
    final now = DateTime.now();
    final trimmedNewTitle = newTitle.trim();
    var changed = 0;

    final updatedSessions = sessions.map((session) {
      final match = _matchEventTitle(
        session,
        eventId: eventId,
        legacyTitle: legacyTitle,
      );
      if (match == null) return session;
      if (session.title == trimmedNewTitle) return session;
      changed++;
      return session.copyWith(title: trimmedNewTitle, updatedAt: now);
    }).toList();

    if (changed > 0) {
      await sessionRepository.saveSessions(updatedSessions);
    }
    _log.info(
      'Event title rename completed: -> "$trimmedNewTitle" '
      '($changed session(s))',
    );
    return changed;
  }

  /// Matches a session to an event the same way history and Insights do: by
  /// event id when present, otherwise by recorded title. A session linked to a
  /// different event is never touched, even when the title matches.
  EventTitleMatch? _matchEventTitle(
    Session session, {
    required String eventId,
    required String? legacyTitle,
  }) {
    final id = session.eventId;
    if (id != null && id.isNotEmpty) {
      return id == eventId ? EventTitleMatch.linked : null;
    }
    final legacy = legacyTitle?.trim().toLowerCase() ?? '';
    if (legacy.isEmpty) return null;
    return session.title.trim().toLowerCase() == legacy
        ? EventTitleMatch.titleOnly
        : null;
  }

  void _validateEventTitleRename({
    required String eventId,
    required String newTitle,
  }) {
    if (eventId.trim().isEmpty) {
      throw ArgumentError('An event id is required');
    }
    if (newTitle.trim().isEmpty) {
      throw ArgumentError('A new event name is required');
    }
  }

  /// Finds live member records that share a normalised display name.
  ///
  /// Includes auto-singletons ("Loners"), which the family duplicate banner
  /// ignores, and de-duplicates the same member id referenced by more than one
  /// family. Groups are suggestions only; nothing is merged here.
  Future<List<DuplicateMemberGroup>> findDuplicateMembers() async {
    final families = await _getFamilies();
    final sessions = await _getSessions();

    final marksByMemberId = <String, int>{};
    final unlinkedByName = <String, int>{};
    for (final session in sessions) {
      if (session.deletedAt != null) continue;
      for (final r in session.records) {
        final mid = r.memberId;
        if (mid != null && mid.trim().isNotEmpty) {
          marksByMemberId[mid] = (marksByMemberId[mid] ?? 0) + 1;
        } else {
          final key = DuplicateMemberGroup.normaliseName(r.attendee);
          if (key.isNotEmpty) {
            unlinkedByName[key] = (unlinkedByName[key] ?? 0) + 1;
          }
        }
      }
    }

    // The same person may be referenced by a real family and a leftover
    // auto-singleton. Show one occurrence, preferring the real family.
    final occurrencesById = <String, DuplicateMemberOccurrence>{};
    for (final family in families) {
      if (family.deletedAt != null) continue;
      for (final member in family.members) {
        if (member.deletedAt != null) continue;
        final occurrence = DuplicateMemberOccurrence(
          member: member,
          family: family,
          linkedMarkCount: marksByMemberId[member.id] ?? 0,
        );
        final existing = occurrencesById[member.id];
        if (existing == null || (existing.isLoner && !occurrence.isLoner)) {
          occurrencesById[member.id] = occurrence;
        }
      }
    }

    final byName = <String, List<DuplicateMemberOccurrence>>{};
    for (final occurrence in occurrencesById.values) {
      final key =
          DuplicateMemberGroup.normaliseName(occurrence.member.displayName);
      if (key.isEmpty) continue;
      byName.putIfAbsent(key, () => []).add(occurrence);
    }

    final groups = <DuplicateMemberGroup>[];
    for (final entry in byName.entries) {
      if (entry.value.length < 2) continue;
      entry.value.sort(_compareDuplicateOccurrences);
      groups.add(DuplicateMemberGroup(
        displayName: entry.value.first.member.displayName,
        occurrences: List.unmodifiable(entry.value),
        unlinkedMarkCount: unlinkedByName[entry.key] ?? 0,
      ));
    }
    groups.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return groups;
  }

  static int _compareDuplicateOccurrences(
    DuplicateMemberOccurrence a,
    DuplicateMemberOccurrence b,
  ) {
    final marks = b.linkedMarkCount.compareTo(a.linkedMarkCount);
    if (marks != 0) return marks;
    if (a.isLoner != b.isLoner) return a.isLoner ? 1 : -1;
    // Use precomputed lowercase display name to eliminate repeated string allocations
    // during O(N log N) sorting of duplicate member occurrences.
    final family = a.family.displayNameLowercase
        .compareTo(b.family.displayNameLowercase);
    if (family != 0) return family;
    return a.member.id.compareTo(b.member.id);
  }

  /// Simulates [plans] without writing. Matching is by member id only, so a
  /// different person who happens to share the same text is never touched.
  Future<BulkDryRunResult> simulateMergeMembers(
    List<MemberMergePlan> plans, {
    bool updateRoster = true,
  }) async {
    _validateMergePlans(plans);
    if (plans.isEmpty) {
      return const BulkDryRunResult(
        sessionsAffected: 0,
        marksUpdated: 0,
        collisionsPruned: 0,
        rosterMembersUpdated: 0,
        rosterMembersRemoved: 0,
        affectedSessionTitles: [],
      );
    }

    final families = await _getFamilies();
    final sessions = await _getSessions();
    final plansBySource = {for (final p in plans) p.sourceMemberId: p};
    final targetIds = plans.map((p) => p.targetMemberId).toSet();

    var rosterMembersRemoved = 0;
    if (updateRoster) {
      for (final f in families) {
        for (final m in f.members) {
          if (m.deletedAt == null && plansBySource.containsKey(m.id)) {
            rosterMembersRemoved++;
          }
        }
      }
    }

    var sessionsAffected = 0;
    var marksUpdated = 0;
    var collisionsPruned = 0;
    final affectedSessionTitles = <String>[];

    for (final session in sessions) {
      final targetPresent = <String>{
        for (final r in session.records)
          if (r.memberId != null &&
              targetIds.contains(r.memberId) &&
              !plansBySource.containsKey(r.memberId))
            r.memberId!,
      };
      var sourceMatches = 0;
      var collisions = 0;
      for (final r in session.records) {
        final plan = plansBySource[r.memberId];
        if (plan == null) continue;
        sourceMatches++;
        if (targetPresent.contains(plan.targetMemberId)) {
          collisions++;
        } else {
          targetPresent.add(plan.targetMemberId);
        }
      }
      if (sourceMatches == 0) continue;
      sessionsAffected++;
      marksUpdated += sourceMatches;
      collisionsPruned += collisions;
      final dateStr = DateFormat('MMM dd, yyyy').format(session.sessionDate);
      affectedSessionTitles.add('${session.title} ($dateStr)');
    }

    return BulkDryRunResult(
      sessionsAffected: sessionsAffected,
      marksUpdated: marksUpdated,
      collisionsPruned: collisionsPruned,
      rosterMembersUpdated: 0,
      rosterMembersRemoved: rosterMembersRemoved,
      affectedSessionTitles: affectedSessionTitles,
    );
  }

  /// Applies [plans] by member id. Source records are repointed to the target
  /// and a source record that collides with an existing target mark in the
  /// same session is pruned.
  Future<void> executeMergeMembers(
    List<MemberMergePlan> plans, {
    bool updateRoster = true,
  }) async {
    _validateMergePlans(plans);
    if (plans.isEmpty) return;

    final families = await _getFamilies();
    final sessions = await _getSessions();
    final plansBySource = {for (final p in plans) p.sourceMemberId: p};
    final targetIds = plans.map((p) => p.targetMemberId).toSet();
    final now = DateTime.now();

    if (updateRoster) {
      var changed = false;
      final updatedFamilies = families.map((f) {
        final remaining =
            f.members.where((m) => !plansBySource.containsKey(m.id)).toList();
        if (remaining.length == f.members.length) return f;
        changed = true;
        return f.copyWith(members: remaining, updatedAt: now);
      }).toList();
      if (changed) await attendanceRepository.saveFamilies(updatedFamilies);
    }

    var sessionsChanged = false;
    final updatedSessions = sessions.map((session) {
      final targetPresent = <String>{
        for (final r in session.records)
          if (r.memberId != null &&
              targetIds.contains(r.memberId) &&
              !plansBySource.containsKey(r.memberId))
            r.memberId!,
      };
      var modified = false;
      final records = <SessionRecord>[];
      for (final r in session.records) {
        final plan = plansBySource[r.memberId];
        if (plan == null) {
          records.add(r);
          continue;
        }
        modified = true;
        if (targetPresent.contains(plan.targetMemberId)) {
          continue;
        }
        targetPresent.add(plan.targetMemberId);
        records.add(r.copyWith(
          memberId: plan.targetMemberId,
          attendee: plan.targetName,
        ));
      }
      if (!modified) return session;
      sessionsChanged = true;
      return session.copyWith(records: records, updatedAt: now);
    }).toList();

    if (sessionsChanged) {
      await sessionRepository.saveSessions(updatedSessions);
    }
    _log.info('Merged ${plans.length} duplicate member record(s) by id');
  }

  void _validateMergePlans(List<MemberMergePlan> plans) {
    final sources = <String>{};
    final targets = <String>{};
    for (final plan in plans) {
      if (plan.sourceMemberId == plan.targetMemberId) {
        throw ArgumentError('A member cannot be merged into themselves');
      }
      if (!sources.add(plan.sourceMemberId)) {
        throw ArgumentError('Duplicate source member ${plan.sourceMemberId}');
      }
      targets.add(plan.targetMemberId);
    }
    for (final target in targets) {
      if (sources.contains(target)) {
        throw ArgumentError('A merge target cannot also be a source');
      }
    }
  }
}
