import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/maintenance/bulk_maintenance_service.dart';
import '../../../data/session.dart';
import '../../../data/session_record.dart';
import '../../../data/session_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/attendance_status.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';
import '../../hub/data/event_repository.dart';
import '../../hub/domain/event.dart';

final _log = AppLogger('StorageInspector');

const inspectorDismissedPrefsKey = 'inspector_dismissed_suggestions';

/// A database record item extracted by the storage inspector for inspection,
/// review suggestions, and maintenance.
class DbRecord {
  const DbRecord({
    required this.id,
    required this.table,
    required this.title,
    required this.meta,
    required this.fields,
    this.flag,
    this.note,
  });

  final String id;
  final String table;
  final String title;
  final String meta;
  final String? flag; // 'hidden' | 'orphan' | 'duplicate' | null
  final String? note;
  final Map<String, String> fields;

  bool get isIssue => flag == 'orphan' || flag == 'duplicate';
  bool get isHidden => flag == 'hidden';
  String get uniqueKey => '${table}_$id';
}

/// Lookups the storage inspector uses to explain a record in context: the
/// session a mark sits in, what else was recorded for the same event and
/// date, and which live members a dangling mark could belong to.
class InspectorIndex {
  InspectorIndex({
    required this.events,
    required this.sessions,
    required this.families,
  });

  final List<Event> events;
  final List<Session> sessions;
  final List<Family> families;

  static String slotOf(Session s) =>
      '${s.title.trim().toLowerCase()}|${DateFormat('yyyy-MM-dd').format(s.sessionDate)}';

  Session? session(String? id) {
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  Event? event(String? id) {
    for (final e in events) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Other live sessions for the same event title and date.
  List<Session> siblings(Session s) => sessions
      .where((o) => o.id != s.id && o.deletedAt == null && slotOf(o) == slotOf(s))
      .toList();

  bool isLiveMember(String? id) => liveMembers().any((m) => m.$1.id == id);

  List<(Member, Family)> liveMembers() => [
        for (final f in families)
          if (f.deletedAt == null)
            for (final m in f.members)
              if (m.deletedAt == null) (m, f),
      ];

  /// Live members whose display or canonical name matches [name].
  List<(Member, Family)> liveMembersNamed(String name) {
    final n = name.trim().toLowerCase();
    return liveMembers()
        .where((e) =>
            e.$1.displayName.trim().toLowerCase() == n ||
            e.$1.canonicalName.trim().toLowerCase() == n)
        .toList();
  }

  /// Index of the mark in [s] identified by its person and recorded-at time.
  static int markIndex(Session s, {String? memberId, required String attendee, required int recordedAtMs}) =>
      s.records.indexWhere((r) =>
          (memberId != null ? r.memberId == memberId : r.attendee == attendee) &&
          r.recordedAt.millisecondsSinceEpoch == recordedAtMs);
}

/// An in-memory working copy tracking touched entities across mutations.
class InspectorDraft {
  InspectorDraft(List<Event> events, List<Session> sessions, List<Family> families)
      : events = List.of(events),
        sessions = List.of(sessions),
        families = List.of(families);

  final List<Event> events;
  final List<Session> sessions;
  final List<Family> families;
  final touchedEvents = <String>{};
  final touchedSessions = <String>{};
  final touchedFamilies = <String>{};

  static void _put<T>(List<T> list, T item, bool Function(T) same) {
    final i = list.indexWhere(same);
    i == -1 ? list.add(item) : list[i] = item;
  }

  void putEvent(Event e) {
    _put(events, e, (x) => x.id == e.id);
    touchedEvents.add(e.id);
  }

  void removeEvent(String id) {
    events.removeWhere((e) => e.id == id);
    touchedEvents.add(id);
  }

  void putSession(Session s) {
    _put(sessions, s, (x) => x.id == s.id);
    touchedSessions.add(s.id);
  }

  void removeSession(String id) {
    sessions.removeWhere((s) => s.id == id);
    touchedSessions.add(id);
  }

  void putFamily(Family f) {
    _put(families, f, (x) => x.id == f.id);
    touchedFamilies.add(f.id);
  }

  void removeFamily(String id) {
    families.removeWhere((f) => f.id == id);
    touchedFamilies.add(id);
  }
}

/// The deep Storage Inspector module that encapsulates diagnostic scanning,
/// Review Suggestion heuristics, Dry-Run simulations, and maintenance operations.
class StorageInspector {
  StorageInspector({
    required this.attendanceRepository,
    required this.eventRepository,
    required this.sessionRepository,
    this.prefs,
    BulkMaintenanceService? bulkMaintenanceService,
  }) : bulkService = bulkMaintenanceService ??
            BulkMaintenanceService(
              attendanceRepository: attendanceRepository,
              sessionRepository: sessionRepository,
            );

  final AttendanceRepository attendanceRepository;
  final EventRepository eventRepository;
  final SessionRepository sessionRepository;
  final SharedPreferences? prefs;
  final BulkMaintenanceService bulkService;

  List<Family> _families = [];
  List<Event> _events = [];
  List<Session> _sessions = [];
  List<DbRecord> _allRecords = [];
  final Map<String, List<({String title, DateTime date})>> _memberUsageMap = {};
  final Set<String> _dismissedKeys = {};

  InspectorDraft? _lastBefore;
  InspectorDraft? _lastAfter;

  List<Family> get families => List.unmodifiable(_families);
  List<Event> get events => List.unmodifiable(_events);
  List<Session> get sessions => List.unmodifiable(_sessions);
  List<DbRecord> get allRecords => List.unmodifiable(_allRecords);
  Map<String, List<({String title, DateTime date})>> get memberUsageMap =>
      Map.unmodifiable(_memberUsageMap);
  Set<String> get dismissedKeys => Set.unmodifiable(_dismissedKeys);

  bool get canUndo => _lastBefore != null && _lastAfter != null;

  InspectorIndex get index =>
      InspectorIndex(events: _events, sessions: _sessions, families: _families);

  List<DbRecord> get reviewSuggestions =>
      _allRecords.where(needsReview).toList();

  List<DbRecord> get tombstones =>
      _allRecords.where((r) => r.isHidden).toList();

  List<DbRecord> get orphanedRecords =>
      _allRecords.where((r) => r.flag == 'orphan').toList();

  List<DbRecord> get duplicateMarks =>
      _allRecords.where((r) => r.flag == 'duplicate').toList();

  /// Scans the repositories honestly without downcasts, loading raw records,
  /// evaluating Review Suggestion heuristics, and updating internal state.
  Future<void> scan() async {
    final families = await attendanceRepository.fetchAllFamilies();
    final events = await eventRepository.fetchAllEvents();
    final sessions = await sessionRepository.fetchAllSessions();

    final p = prefs ?? await SharedPreferences.getInstance();
    final dismissed = p.getStringList(inspectorDismissedPrefsKey) ?? const <String>[];

    _dismissedKeys
      ..clear()
      ..addAll(dismissed);

    applyData(families, events, sessions);
  }

  /// Synchronously populates internal state with provided records and rebuilds
  /// diagnostic indices and DbRecords.
  void applyData(
    List<Family> families,
    List<Event> events,
    List<Session> sessions, {
    Iterable<String>? dismissed,
  }) {
    _families = List.of(families);
    _events = List.of(events);
    _sessions = List.of(sessions);

    if (dismissed != null) {
      _dismissedKeys
        ..clear()
        ..addAll(dismissed);
    }

    _memberUsageMap.clear();
    for (final session in sessions) {
      if (session.deletedAt != null) continue;
      for (final record in session.records) {
        if (record.memberId != null) {
          _memberUsageMap
              .putIfAbsent(record.memberId!, () => [])
              .add((title: session.title, date: session.sessionDate));
        }
      }
    }

    _rebuildDbRecords();
  }

  void _rebuildDbRecords() {
    final List<DbRecord> records = [];

    // Map Events
    for (final event in _events) {
      final isDeleted = event.deletedAt != null;
      records.add(DbRecord(
        id: event.id,
        table: 'events',
        title: event.title,
        meta:
            '${event.repeatingDays.isNotEmpty ? event.repeatingDays.map((d) => d.substring(0, 3)).join(', ') : event.frequency} · ${event.time.hour.toString().padLeft(2, '0')}:${event.time.minute.toString().padLeft(2, '0')}',
        flag: isDeleted ? 'hidden' : null,
        note: isDeleted ? 'This event is soft-deleted and hidden in the main app.' : null,
        fields: {
          'id': event.id,
          'title': event.title,
          'frequency': event.frequency,
          'days': event.repeatingDays.toString(),
          'time':
              '${event.time.hour.toString().padLeft(2, '0')}:${event.time.minute.toString().padLeft(2, '0')}',
          'members': '${event.memberIds.length}',
          'date': DateFormat('yyyy-MM-dd').format(event.createdAt),
          'created': DateFormat('yyyy-MM-dd HH:mm').format(event.createdAt),
          'deletedAt': event.deletedAt != null
              ? DateFormat('yyyy-MM-dd HH:mm').format(event.deletedAt!)
              : 'null',
        },
      ));
    }

    // Map Sessions
    for (final session in _sessions) {
      final isDeleted = session.deletedAt != null;
      final eventExists = session.eventId == null ||
          _events.any((e) => e.id == session.eventId && e.deletedAt == null);

      String? flag;
      String? note;
      if (isDeleted) {
        flag = 'hidden';
        note = 'This session is soft-deleted and hidden in the main app.';
      } else if (!eventExists) {
        flag = 'orphan';
        note =
            'This session references event ID ${session.eventId}, which is not in the database or is deleted.';
      } else if (session.records.isEmpty) {
        flag = 'orphan';
        note = 'This session is empty and has no attendance records.';
      }

      records.add(DbRecord(
        id: session.id,
        table: 'sessions',
        title: session.title,
        meta:
            '${session.records.length} marks · ${DateFormat('MMM dd, yyyy').format(session.sessionDate)}',
        flag: flag,
        note: note,
        fields: {
          'id': session.id,
          'event_id': session.eventId ?? '—',
          'date': DateFormat('yyyy-MM-dd').format(session.sessionDate),
          'formatted_date': DateFormat('MMM dd, yyyy').format(session.sessionDate),
          'records': '${session.records.length}',
          'created_by': session.createdBy,
          'deletedAt': session.deletedAt != null
              ? DateFormat('yyyy-MM-dd HH:mm').format(session.deletedAt!)
              : 'null',
        },
      ));
    }

    // Active member ID set for orphaned mark detection
    final activeMemberIds = <String>{};
    for (final family in _families) {
      if (family.deletedAt != null) continue;
      for (final member in family.members) {
        if (member.deletedAt == null) {
          activeMemberIds.add(member.id);
        }
      }
    }

    // Map Members
    final seenMemberIds = <String>{};
    for (final family in _families) {
      for (final member in family.members) {
        if (!seenMemberIds.add(member.id)) continue;
        final isDeleted = member.deletedAt != null || family.deletedAt != null;
        records.add(DbRecord(
          id: member.id,
          table: 'members',
          title: member.displayName,
          meta: 'Family: ${family.displayName}',
          flag: isDeleted ? 'hidden' : null,
          note: isDeleted
              ? 'This member is soft-deleted or belongs to a soft-deleted family.'
              : null,
          fields: {
            'id': member.id,
            'name': member.displayName,
            'family_id': family.id,
            'isVisitor': '${member.isVisitor}',
            'deletedAt': member.deletedAt != null
                ? DateFormat('yyyy-MM-dd HH:mm').format(member.deletedAt!)
                : 'null',
          },
        ));
      }
    }

    // Map Families
    for (final family in _families) {
      final isDeleted = family.deletedAt != null;
      final isEmpty = family.members.isEmpty;

      String? flag;
      String? note;
      if (isDeleted) {
        flag = 'hidden';
        note = 'This family is soft-deleted and hidden in the main app.';
      } else if (isEmpty) {
        flag = 'orphan';
        note = 'This family group has no members.';
      }

      records.add(DbRecord(
        id: family.id,
        table: 'families',
        title: family.displayName,
        meta: '${family.members.length} members',
        flag: flag,
        note: note,
        fields: {
          'id': family.id,
          'name': family.displayName,
          'isAutoSingleton': '${family.isAutoSingleton}',
          'members': '${family.members.length}',
          'deletedAt': family.deletedAt != null
              ? DateFormat('yyyy-MM-dd HH:mm').format(family.deletedAt!)
              : 'null',
        },
      ));
    }

    // Map Attendance (marks) & Track Duplicates
    final Map<String, String> seenAttendanceKeys = {};
    for (final session in _sessions) {
      final sessionDateStr = DateFormat('yyyy-MM-dd').format(session.sessionDate);
      final sessionDateFormatted = DateFormat('MMM dd, yyyy').format(session.sessionDate);

      for (final record in session.records) {
        final isSessionDeleted = session.deletedAt != null;
        final isMemberDeleted =
            record.memberId != null && !activeMemberIds.contains(record.memberId);
        final compositeKey =
            '${session.title.trim().toLowerCase()}|$sessionDateStr|${record.attendee.trim().toLowerCase()}';

        String? flag;
        String? note;
        if (isSessionDeleted) {
          flag = 'hidden';
          note = 'This attendance mark belongs to a soft-deleted session.';
        } else if (isMemberDeleted) {
          flag = 'orphan';
          note =
              'This attendance mark references member ID ${record.memberId}, who has been deleted or is missing from the roster.';
        } else if (seenAttendanceKeys.containsKey(compositeKey)) {
          flag = 'duplicate';
          note =
              'Duplicate attendance entry detected: matches event "${session.title}", date "$sessionDateStr", and attendant "${record.attendee}".';
        } else {
          seenAttendanceKeys[compositeKey] =
              '${session.id}_${record.memberId ?? record.attendee}';
        }

        final recordKey =
            '${session.id}_${record.memberId ?? record.attendee}_${record.recordedAt.millisecondsSinceEpoch}';

        records.add(DbRecord(
          id: recordKey,
          table: 'attendance',
          title: 'mark · ${record.status.name}',
          meta: '${session.title} · ${record.attendee} · $sessionDateFormatted',
          flag: flag,
          note: note,
          fields: {
            'session_id': session.id,
            'member_id': record.memberId ?? '—',
            'attendee': record.attendee,
            'status': record.status.name,
            'date': sessionDateStr,
            'formatted_date': sessionDateFormatted,
            'recordedAt':
                DateFormat('yyyy-MM-dd HH:mm:ss').format(record.recordedAt),
            'recordedAtMs': '${record.recordedAt.millisecondsSinceEpoch}',
            'recordedBy': record.recordedBy,
          },
        ));
      }
    }

    _allRecords = records;
  }

  /// Whether [r] is an active issue that has not been dismissed on this device.
  bool needsReview(DbRecord r) => r.isIssue && !_dismissedKeys.contains(r.uniqueKey);

  bool isDismissed(String uniqueKey) => _dismissedKeys.contains(uniqueKey);

  /// Dismisses or un-dismisses a review suggestion, persisting the preference.
  Future<void> setDismissed(DbRecord r, bool dismissed) async {
    await setDismissedByKey(r.uniqueKey, dismissed);
  }

  /// Dismisses or un-dismisses a review suggestion by unique key.
  Future<void> setDismissedByKey(String uniqueKey, bool dismissed) async {
    if (dismissed) {
      _dismissedKeys.add(uniqueKey);
    } else {
      _dismissedKeys.remove(uniqueKey);
    }
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      await p.setStringList(inspectorDismissedPrefsKey, _dismissedKeys.toList());
    } catch (e, st) {
      _log.error('Failed to persist dismissed suggestions', e, st);
    }
  }

  int markIndex(Session s, DbRecord r) => InspectorIndex.markIndex(
        s,
        memberId: r.fields['member_id'] == '—' ? null : r.fields['member_id'],
        attendee: r.fields['attendee']!,
        recordedAtMs: int.parse(r.fields['recordedAtMs']!),
      );

  Future<void> _save(InspectorDraft d) async {
    final saves = <Future<void>>[];
    if (d.touchedEvents.isNotEmpty) {
      saves.add(eventRepository.saveEvents(d.events));
    }
    if (d.touchedSessions.isNotEmpty) {
      saves.add(sessionRepository.saveSessions(d.sessions));
    }
    if (d.touchedFamilies.isNotEmpty) {
      saves.add(attendanceRepository.saveFamilies(d.families));
    }
    await Future.wait(saves);
    applyData(d.families, d.events, d.sessions);
  }

  /// Applies a mutation function to working copies of data and saves changes.
  Future<void> mutate(void Function(InspectorDraft d) edit) async {
    final before = InspectorDraft(_events, _sessions, _families);
    final after = InspectorDraft(_events, _sessions, _families);
    edit(after);
    await _save(after);
    _lastBefore = before;
    _lastAfter = after;
  }

  /// Reverts the most recent mutation, restoring previous records with a fresh
  /// updatedAt timestamp so that cloud synchronization respects the rollback.
  Future<void> undo() async {
    if (!canUndo) return;
    final before = _lastBefore!;
    final after = _lastAfter!;
    final now = DateTime.now();
    final d = InspectorDraft(_events, _sessions, _families);
    for (final id in after.touchedEvents) {
      final prev = before.events.where((e) => e.id == id).firstOrNull;
      prev == null ? d.removeEvent(id) : d.putEvent(prev.copyWith(updatedAt: now));
    }
    for (final id in after.touchedSessions) {
      final prev = before.sessions.where((s) => s.id == id).firstOrNull;
      prev == null ? d.removeSession(id) : d.putSession(prev.copyWith(updatedAt: now));
    }
    for (final id in after.touchedFamilies) {
      final prev = before.families.where((f) => f.id == id).firstOrNull;
      prev == null ? d.removeFamily(id) : d.putFamily(prev.copyWith(updatedAt: now));
    }
    await _save(d);
    _lastBefore = null;
    _lastAfter = null;
  }

  /// Deletes a record: leaves a soft-delete tombstone if active, or permanently
  /// removes if already soft-deleted. Attendance marks are removed from session records.
  Future<void> deleteRecord(DbRecord r) async {
    final now = DateTime.now();
    await mutate((d) {
      switch (r.table) {
        case 'events':
          final e = d.events.firstWhere((e) => e.id == r.id);
          e.deletedAt == null
              ? d.putEvent(e.copyWith(deletedAt: now, updatedAt: now))
              : d.removeEvent(e.id);
        case 'sessions':
          final s = d.sessions.firstWhere((s) => s.id == r.id);
          s.deletedAt == null
              ? d.putSession(s.copyWith(deletedAt: now, updatedAt: now))
              : d.removeSession(s.id);
        case 'families':
          final f = d.families.firstWhere((f) => f.id == r.id);
          f.deletedAt == null
              ? d.putFamily(f.copyWith(deletedAt: now, updatedAt: now))
              : d.removeFamily(f.id);
        case 'members':
          for (final f in d.families.where((f) => f.members.any((m) => m.id == r.id)).toList()) {
            d.putFamily(f.copyWith(
              members: [
                for (final m in f.members)
                  if (m.id != r.id)
                    m
                  else if (m.deletedAt == null)
                    m.copyWith(deletedAt: now, updatedAt: now),
              ],
              updatedAt: now,
            ));
          }
        case 'attendance':
          final s = d.sessions.firstWhere((s) => s.id == r.fields['session_id']);
          final i = markIndex(s, r);
          if (i != -1) {
            d.putSession(
                s.copyWith(records: [...s.records]..removeAt(i), updatedAt: now));
          }
      }
    });
  }

  /// Restores a soft-deleted tombstone record, clearing its deletedAt timestamp.
  Future<void> restoreRecord(DbRecord r) async {
    final now = DateTime.now();
    await mutate((d) {
      switch (r.table) {
        case 'events':
          final e = d.events.firstWhere((e) => e.id == r.id);
          d.putEvent(e.copyWith(clearDeletedAt: true, updatedAt: now));
        case 'sessions':
          final s = d.sessions.firstWhere((s) => s.id == r.id);
          d.putSession(s.copyWith(clearDeletedAt: true, updatedAt: now));
        case 'families':
          final f = d.families.firstWhere((f) => f.id == r.id);
          d.putFamily(f.copyWith(clearDeletedAt: true, updatedAt: now));
        case 'members':
          final f = d.families.firstWhere((f) => f.members.any((m) => m.id == r.id));
          d.putFamily(f.copyWith(
            clearDeletedAt: true,
            updatedAt: now,
            members: [
              for (final m in f.members)
                m.id == r.id
                    ? m.copyWith(clearDeletedAt: true, updatedAt: now)
                    : m,
            ],
          ));
      }
    });
  }

  /// Edits an attendance mark in its corresponding session using [change].
  Future<void> editMark(
    DbRecord r,
    SessionRecord Function(SessionRecord mark) change,
  ) async {
    await mutate((d) {
      final s = d.sessions.firstWhere((s) => s.id == r.fields['session_id']);
      final i = markIndex(s, r);
      if (i == -1) return;
      d.putSession(s.copyWith(
        records: [...s.records]..[i] = change(s.records[i]),
        updatedAt: DateTime.now(),
      ));
    });
  }

  /// Relinks an orphaned attendance mark to a live roster [member].
  Future<void> relinkMark(DbRecord r, Member member) => editMark(
        r,
        (m) => m.copyWith(memberId: member.id, attendee: member.displayName),
      );

  /// Retains an attendance mark as an unlinked Guest Mark with a null member ID.
  Future<void> keepMarkAsGuest(DbRecord r) => editMark(
        r,
        (m) => SessionRecord(
          attendee: m.attendee,
          status: m.status,
          recordedAt: m.recordedAt,
          recordedBy: m.recordedBy,
          isLate: m.isLate,
        ),
      );

  /// Updates the attendance status of a mark.
  Future<void> updateMarkStatus(DbRecord r, AttendanceStatus status) => editMark(
        r,
        (m) => m.copyWith(status: status),
      );

  /// Simulates a bulk merge without applying mutations (Dry-Run Validation).
  Future<BulkDryRunResult> simulateMerge({
    required String? sourceIdentifier,
    required String sourceName,
    required String? targetMemberId,
    required String targetName,
    required bool updateRoster,
  }) =>
      bulkService.simulateMerge(
        sourceIdentifier: sourceIdentifier,
        sourceName: sourceName,
        targetMemberId: targetMemberId,
        targetName: targetName,
        updateRoster: updateRoster,
      );

  /// Executes an explicit bulk merge, consolidating marks and pruning collisions.
  Future<void> executeMerge({
    required String? sourceIdentifier,
    required String sourceName,
    required String? targetMemberId,
    required String targetName,
    required bool updateRoster,
  }) async {
    await bulkService.executeMerge(
      sourceIdentifier: sourceIdentifier,
      sourceName: sourceName,
      targetMemberId: targetMemberId,
      targetName: targetName,
      updateRoster: updateRoster,
    );
    await scan();
  }

  /// Simulates a bulk rename without applying mutations.
  Future<BulkDryRunResult> simulateRename({
    required String oldName,
    required String newName,
    required String? memberId,
    required bool updateRoster,
  }) =>
      bulkService.simulateRename(
        oldName: oldName,
        newName: newName,
        memberId: memberId,
        updateRoster: updateRoster,
      );

  /// Executes an explicit bulk rename.
  Future<void> executeRename({
    required String oldName,
    required String newName,
    required String? memberId,
    required bool updateRoster,
  }) async {
    await bulkService.executeRename(
      oldName: oldName,
      newName: newName,
      memberId: memberId,
      updateRoster: updateRoster,
    );
    await scan();
  }
}
