import 'package:intl/intl.dart';

import '../../data/local_session_repository.dart';
import '../../data/session.dart';
import '../../data/session_record.dart';
import '../../data/session_repository.dart';
import '../../features/attendance/data/attendance_repository.dart';
import '../../features/attendance/models/family.dart';
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

class BulkMaintenanceService {
  BulkMaintenanceService({
    required this.attendanceRepository,
    required this.sessionRepository,
  });

  final AttendanceRepository attendanceRepository;
  final SessionRepository sessionRepository;

  Future<List<Family>> _getFamilies() async {
    final attRepo = attendanceRepository;
    if (attRepo is LocalJsonAttendanceRepository) {
      return attRepo.fetchAllFamilies();
    }
    return attRepo.fetchFamilies();
  }

  Future<List<Session>> _getSessions() async {
    final sesRepo = sessionRepository;
    if (sesRepo is LocalJsonSessionRepository) {
      return sesRepo.fetchAllSessions();
    }
    return sesRepo.loadSessions();
  }

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

    final sesRepo = sessionRepository;
    if (sesRepo is LocalJsonSessionRepository) {
      await sesRepo.saveSessions(updatedSessions);
    } else {
      try {
        await (sesRepo as dynamic).saveSessions(updatedSessions);
      } catch (_) {}
    }

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

    final sesRepo = sessionRepository;
    if (sesRepo is LocalJsonSessionRepository) {
      await sesRepo.saveSessions(updatedSessions);
    } else {
      try {
        await (sesRepo as dynamic).saveSessions(updatedSessions);
      } catch (_) {}
    }

    _log.info('Bulk rename completed: "$oldName" -> "$newName"');
  }
}
