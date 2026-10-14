import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../data/session.dart';
import '../../../../data/session_record.dart';
import '../../../../data/session_repository.dart';
import '../../hub/data/event_repository.dart';
import '../../hub/domain/event.dart';
import '../data/attendance_repository.dart';
import '../models/attendance_status.dart';
import '../models/family.dart';
import '../models/member.dart';
import '../utils/bulk_attendance.dart';

final _log = AppLogger('AttendanceMarkingSession');

/// Result of applying bulk smart defaults across a marking session.
typedef BulkSmartResult = ({List<SessionRecord> records, int resolved});

/// The in-process domain module and state coordinator governing active
/// attendance recording, optimistic persistence serialization, undo history,
/// and member/guest identity resolution for a session.
class AttendanceMarkingSession extends ChangeNotifier {
  AttendanceMarkingSession({
    required Session session,
    required List<Member> baseMembers,
    List<Family>? families,
    Event? event,
    required SessionRepository sessionRepository,
    AttendanceRepository? attendanceRepository,
    EventRepository? eventRepository,
    String defaultActor = 'User',
    bool streamUpdates = false,
  })  : _sessionRepository = sessionRepository,
        _attendanceRepository = attendanceRepository,
        _eventRepository = eventRepository,
        _defaultActor = defaultActor,
        _currentSession = session,
        _event = event {
    _sessionMembers.addAll(baseMembers);
    if (families != null && families.isNotEmpty) {
      _baseFamilies = List.from(families);
    }
    _snapshotBaseline(_currentSession);
    _updateTouchedTracking(_currentSession);

    if (streamUpdates) {
      if (_attendanceRepository != null) {
        _membersSub = _attendanceRepository.streamFamilies().listen((f) {
          updateFamilies(f);
        });
      }
      if (_eventRepository != null && _event?.id != null) {
        final eventId = _event!.id;
        _eventsSub = _eventRepository.streamEvents().listen((events) {
          for (final e in events) {
            if (e.id == eventId) {
              updateEvent(e);
              break;
            }
          }
        });
      }
    }
  }

  final SessionRepository _sessionRepository;
  final AttendanceRepository? _attendanceRepository;
  final EventRepository? _eventRepository;
  final String _defaultActor;

  Session _currentSession;
  Event? _event;
  final List<Member> _sessionMembers = [];
  List<Family>? _baseFamilies;
  List<Family> _allFamilies = const [];

  final List<Session> _undoStack = [];
  static const int _maxUndoDepth = 50;

  final Map<String, AttendanceStatus> _baselineStatus = {};
  late final List<SessionRecord> _baselineRecords;

  final Set<String> _touchedMemberIds = {};
  final Set<String> _touchedMemberNames = {};

  Future<void> _saveQueue = Future.value();
  final StreamController<Object> _saveErrorController =
      StreamController<Object>.broadcast();

  StreamSubscription? _membersSub;
  StreamSubscription? _eventsSub;

  // ─────────────────────────────────────────────────────────────────────────
  // Public Properties
  // ─────────────────────────────────────────────────────────────────────────

  /// Current immutable session state.
  Session get session => _currentSession;

  /// Current event context, if available.
  Event? get event => _event;

  /// All members in this session (including newly added members/guests).
  List<Member> get sessionMembers => List.unmodifiable(_sessionMembers);

  /// Resolved families for this session.
  List<Family> get sessionFamilies {
    if (_baseFamilies != null && _baseFamilies!.isNotEmpty) {
      return _baseFamilies!;
    }
    if (_allFamilies.isNotEmpty) {
      final eventIds = _sessionMembers.map((m) => m.id).toSet();
      final result = <Family>[];
      for (final f in _allFamilies) {
        final filtered =
            f.members.where((m) => eventIds.contains(m.id)).toList();
        if (filtered.isEmpty) continue;
        result.add(f.copyWith(members: filtered));
      }
      if (result.isNotEmpty) return result;
    }
    return [
      Family(
        id: '_synthetic_all',
        displayName: 'All members',
        members: _sessionMembers,
      ),
    ];
  }

  /// Initial preseed baseline status map for confirm mode diff tracking.
  Map<String, AttendanceStatus> get baselineStatus =>
      Map.unmodifiable(_baselineStatus);

  /// Whether an undo action is available.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Depth of the undo stack.
  int get undoDepth => _undoStack.length;

  /// Whether the user has made any non-preseed marks in this session.
  bool get hasUserEdits =>
      _touchedMemberIds.isNotEmpty || _touchedMemberNames.isNotEmpty;

  /// Set of member IDs touched by user edits in this session.
  Set<String> get touchedMemberIds => Set.unmodifiable(_touchedMemberIds);

  /// Set of attendee names touched by user edits in this session.
  Set<String> get touchedMemberNames => Set.unmodifiable(_touchedMemberNames);

  /// Stream of save errors emitted during background writes.
  Stream<Object> get saveErrors => _saveErrorController.stream;

  /// Future of all currently enqueued background writes.
  Future<void> get pendingSaves => _saveQueue;

  /// Count of members whose current status differs from their baseline preseed.
  int get changedCount {
    var count = 0;
    for (final m in _sessionMembers) {
      if (isChanged(m)) count++;
    }
    return count;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Identity Resolution Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Normalizes an ID string so that empty strings, whitespace, and synthetic
  /// visitor identifiers (e.g. 'visitor_...') resolve to null.
  static String? cleanMemberId(String? id) {
    if (id == null) return null;
    final trimmed = id.trim();
    if (trimmed.isEmpty || trimmed.startsWith('visitor_')) return null;
    return trimmed;
  }

  /// Whether a session record represents a guest mark with a null/empty member ID.
  static bool isGuestRecord(SessionRecord record) =>
      cleanMemberId(record.memberId) == null;

  /// Whether a member represents an in-session visitor or guest.
  static bool isGuestMember(Member member) =>
      member.isVisitor || cleanMemberId(member.id) == null;

  bool _matchesRecord(
    SessionRecord record, {
    String? memberId,
    required String attendeeName,
  }) {
    final cleanId = cleanMemberId(memberId);
    final recordCleanId = cleanMemberId(record.memberId);
    if (cleanId != null) {
      return recordCleanId == cleanId;
    }
    return recordCleanId == null && record.attendee == attendeeName;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Query Methods
  // ─────────────────────────────────────────────────────────────────────────

  /// Finds the session record for [member], if one exists.
  SessionRecord? findRecordFor(Member member) {
    final cleanId = cleanMemberId(member.isVisitor ? null : member.id);
    if (cleanId != null) {
      for (final r in _currentSession.records) {
        if (cleanMemberId(r.memberId) == cleanId) return r;
      }
    }
    for (final r in _currentSession.records) {
      if (cleanMemberId(r.memberId) == null &&
          r.attendee == member.displayName) {
        return r;
      }
    }
    return null;
  }

  /// Returns the current status of [member], defaulting to [AttendanceStatus.absent].
  AttendanceStatus getStatus(Member member) {
    return findRecordFor(member)?.status ?? AttendanceStatus.absent;
  }

  /// Returns whether [member] is flagged as present-but-late.
  bool isLate(Member member) {
    return findRecordFor(member)?.isLate ?? false;
  }

  /// Returns the baseline preseed status for [member], if one was recorded.
  AttendanceStatus? baselineFor(Member member) {
    final cleanId = cleanMemberId(member.isVisitor ? null : member.id);
    if (cleanId != null && _baselineStatus.containsKey(cleanId)) {
      return _baselineStatus[cleanId];
    }
    return _baselineStatus[member.displayName];
  }

  /// Returns whether [member]'s current status differs from their preseed baseline.
  bool isChanged(Member member) {
    final baseline = baselineFor(member);
    if (baseline == null) return false;
    return getStatus(member) != baseline;
  }

  /// Returns whether [member] has been explicitly touched by a user action.
  bool isTouched(Member member) {
    final cleanId = cleanMemberId(member.isVisitor ? null : member.id);
    if (cleanId != null && _touchedMemberIds.contains(cleanId)) {
      return true;
    }
    return _touchedMemberNames.contains(member.displayName);
  }

  /// Resolves the family containing [member], if any.
  Family? familyForMember(Member member) {
    for (final f in sessionFamilies) {
      if (f.members.any((m) => m.id == member.id)) return f;
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Marking Mutations
  // ─────────────────────────────────────────────────────────────────────────

  /// Records attendance status for [member] immediately in memory and enqueues
  /// disk persistence in the background write queue.
  Future<void> markMember(
    Member member,
    AttendanceStatus status, {
    bool? isLate,
    String? actor,
  }) async {
    _pushUndoState();
    final cleanId = cleanMemberId(member.isVisitor ? null : member.id);
    final now = DateTime.now();

    final updatedRecords = List<SessionRecord>.from(_currentSession.records);
    SessionRecord? existing;
    for (var i = 0; i < updatedRecords.length; i++) {
      if (_matchesRecord(
        updatedRecords[i],
        memberId: cleanId,
        attendeeName: member.displayName,
      )) {
        existing = updatedRecords.removeAt(i);
        break;
      }
    }

    final effectiveLate = isLate ??
        (status == AttendanceStatus.absent
            ? false
            : (existing?.isLate ?? false));

    final newRecord = SessionRecord(
      memberId: cleanId,
      attendee: member.displayName,
      status: status,
      isLate: effectiveLate,
      recordedAt: now,
      recordedBy: actor ?? _defaultActor,
    );
    updatedRecords.add(newRecord);

    final updatedExcluded = List<String>.from(_currentSession.excludedMemberIds);
    if (cleanId != null) {
      updatedExcluded.remove(cleanId);
    }

    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      excludedMemberIds: updatedExcluded,
      updatedAt: now,
    );

    _currentSession = updatedSession;
    _updateTouchedTracking(_currentSession);
    notifyListeners();
    await _enqueueSave(_currentSession, actor: actor);
  }

  /// Convenience toggle for present vs absent.
  Future<void> toggleMember(
    Member member,
    bool isPresent, {
    String? actor,
  }) {
    return markMember(
      member,
      isPresent ? AttendanceStatus.present : AttendanceStatus.absent,
      actor: actor,
    );
  }

  /// Toggles the present-but-late flag on [member]'s existing present record.
  Future<void> toggleLate(Member member, {String? actor}) async {
    final cleanId = cleanMemberId(member.isVisitor ? null : member.id);
    final updatedRecords = List<SessionRecord>.from(_currentSession.records);

    SessionRecord? target;
    var targetIndex = -1;
    for (var i = 0; i < updatedRecords.length; i++) {
      final r = updatedRecords[i];
      final rCleanId = cleanMemberId(r.memberId);
      final byId = cleanId != null && rCleanId == cleanId;
      final byName = rCleanId == null && r.attendee == member.displayName;
      if (byId || byName) {
        target = r;
        targetIndex = i;
        if (byId) break; // member-keyed record wins over a name match
      }
    }
    if (target == null || targetIndex < 0) return;

    _pushUndoState();
    final updatedRecord = target.copyWith(
      isLate: !target.isLate,
      recordedAt: DateTime.now(),
      recordedBy: actor ?? _defaultActor,
    );
    updatedRecords[targetIndex] = updatedRecord;

    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      updatedAt: DateTime.now(),
    );

    _currentSession = updatedSession;
    _updateTouchedTracking(_currentSession);
    notifyListeners();
    await _enqueueSave(_currentSession, actor: actor);
  }

  /// Marks every member of [family] present or absent in a single atomic snapshot.
  Future<void> markFamily(
    Family family,
    bool isPresent, {
    String? actor,
  }) async {
    _pushUndoState();
    final now = DateTime.now();
    final status =
        isPresent ? AttendanceStatus.present : AttendanceStatus.absent;
    final updatedRecords = List<SessionRecord>.from(_currentSession.records);

    for (final m in family.members) {
      final mid = cleanMemberId(m.isVisitor ? null : m.id);
      updatedRecords.removeWhere((r) => _matchesRecord(
            r,
            memberId: mid,
            attendeeName: m.displayName,
          ));
      updatedRecords.add(SessionRecord(
        memberId: mid,
        attendee: m.displayName,
        status: status,
        recordedAt: now,
        recordedBy: actor ?? _defaultActor,
      ));
    }

    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      updatedAt: now,
    );

    _currentSession = updatedSession;
    _updateTouchedTracking(_currentSession);
    notifyListeners();
    await _enqueueSave(_currentSession, actor: actor);
  }

  /// Marks all specified [members] present or absent in a single atomic snapshot.
  Future<void> markAll(
    List<Member> members, {
    required bool present,
    String? actor,
  }) async {
    _pushUndoState();
    final now = DateTime.now();
    final updatedRecords = applyBulkRecords(
      previousRecords: _currentSession.records,
      members: members,
      present: present,
      recordedAt: now,
    );

    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      updatedAt: now,
    );

    _currentSession = updatedSession;
    _updateTouchedTracking(_currentSession);
    notifyListeners();
    await _enqueueSave(_currentSession, actor: actor);
  }

  /// Applies smart defaults based on recent attendance history.
  Future<BulkSmartResult> markAllSmart({
    required List<Member> members,
    required List<Session> recentSessions,
    String? actor,
  }) async {
    _pushUndoState();
    final now = DateTime.now();
    final result = applyBulkSmartRecords(
      previousRecords: _currentSession.records,
      members: members,
      recentSessions: recentSessions,
      recordedAt: now,
    );

    final updatedSession = _currentSession.copyWith(
      records: result.records,
      updatedAt: now,
    );

    _currentSession = updatedSession;
    _updateTouchedTracking(_currentSession);
    notifyListeners();
    await _enqueueSave(_currentSession, actor: actor);
    return result;
  }

  /// Restores every member to their initial preseed status baseline.
  Future<void> resetToBaseline({String? actor}) async {
    _pushUndoState();
    final restored = _currentSession.copyWith(
      records: _baselineRecords,
      updatedAt: DateTime.now(),
    );

    _currentSession = restored;
    _updateTouchedTracking(_currentSession);
    notifyListeners();
    await _enqueueSave(_currentSession, actor: actor);
  }

  /// Restores records from a previously saved snapshot.
  Future<void> restoreRecords(
    List<SessionRecord> previousRecords, {
    String? actor,
  }) async {
    _pushUndoState();
    final restored = _currentSession.copyWith(
      records: previousRecords,
      updatedAt: DateTime.now(),
    );

    _currentSession = restored;
    _updateTouchedTracking(_currentSession);
    notifyListeners();
    await _enqueueSave(_currentSession, actor: actor);
  }

  /// Adds a walk-in guest to the session with a null member ID, preserving
  /// their name snapshot without polluting the Event Roster or Member Directory.
  Future<Member> addGuest(
    String name, {
    AttendanceStatus status = AttendanceStatus.present,
    String? actor,
  }) async {
    return addAttendee(
      name,
      isPresent: status == AttendanceStatus.present,
      isGuest: true,
      actor: actor,
    );
  }

  /// Adds an attendee to the session.
  ///
  /// When [isGuest] is true, records the attendee with a null member ID preserving
  /// their name snapshot without modifying the Member Directory or Event Roster.
  ///
  /// When [isGuest] is false, creates a new regular attendee in the Member Directory
  /// and adds them to the Event Roster, tracking their attendance going forward.
  Future<Member> addAttendee(
    String name, {
    required bool isPresent,
    required bool isGuest,
    Member? existingMember,
    String? actor,
  }) async {
    Member resolved;
    if (existingMember != null) {
      resolved = existingMember;
      await ensureMemberInEvent(existingMember.id);
    } else if (!isGuest && name.trim().isNotEmpty) {
      final trimmed = name.trim();
      final created = await _createGlobalMember(trimmed);
      if (created != null) {
        resolved = created;
        await ensureMemberInEvent(created.id);
      } else {
        resolved = Member(id: '', displayName: trimmed, isVisitor: true);
      }
    } else {
      resolved = Member(id: '', displayName: name.trim(), isVisitor: true);
    }

    final exists = _sessionMembers.any((m) =>
        (resolved.id.isNotEmpty && m.id == resolved.id) ||
        (resolved.id.isEmpty && m.displayName == resolved.displayName));
    if (!exists) {
      _sessionMembers.add(resolved);
    }

    final status =
        isPresent ? AttendanceStatus.present : AttendanceStatus.absent;
    await markMember(resolved, status, actor: actor);
    return resolved;
  }

  /// Ensures that [memberId] is registered in the current event's roster.
  Future<void> ensureMemberInEvent(String memberId) async {
    final ev = _event;
    final repo = _eventRepository;
    if (ev == null || repo == null) return;
    if (ev.memberIds.contains(memberId)) return;

    final updated = ev.copyWith(
      memberIds: [...ev.memberIds, memberId],
      updatedAt: DateTime.now(),
    );
    _event = updated;
    try {
      await repo.updateEvent(updated);
    } catch (e, st) {
      _log.warning('Error adding member to event: $e\n$st');
    }
  }

  Future<Member?> _createGlobalMember(String name) async {
    final repo = _attendanceRepository;
    if (repo == null) return null;
    try {
      final family = await repo.addFamily(name, isAutoSingleton: true);
      final member = Member(id: const Uuid().v4(), displayName: name);
      await repo.addMember(family.id, member);
      return member;
    } catch (e, st) {
      _log.warning('Error creating global member: $e\n$st');
      return null;
    }
  }

  /// Corrects the attendee display name in this session snapshot only.
  Future<void> editMemberName(
    Member member,
    String newName, {
    String? actor,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == member.displayName.trim()) return;

    _pushUndoState();
    final cleanId = cleanMemberId(member.isVisitor ? null : member.id);
    final isVisitor = isGuestMember(member);
    final updatedRecords = _currentSession.records.map((r) {
      final matchesById =
          !isVisitor && cleanId != null && cleanMemberId(r.memberId) == cleanId;
      final matchesByName = isVisitor &&
          cleanMemberId(r.memberId) == null &&
          r.attendee == member.displayName;

      if (matchesById || matchesByName) {
        return r.copyWith(attendee: trimmed);
      }
      return r;
    }).toList();

    for (var i = 0; i < _sessionMembers.length; i++) {
      final m = _sessionMembers[i];
      final mCleanId = cleanMemberId(m.id);
      if ((cleanId != null && mCleanId == cleanId) ||
          (isVisitor && m.displayName == member.displayName)) {
        _sessionMembers[i] = m.copyWith(displayName: trimmed);
      }
    }

    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      updatedAt: DateTime.now(),
    );

    _currentSession = updatedSession;
    _updateTouchedTracking(_currentSession);
    notifyListeners();
    await _enqueueSave(_currentSession, actor: actor);
  }

  /// Removes [member] from this session snapshot and marks them as excluded.
  Future<void> removeMemberFromSession(
    Member member, {
    String? actor,
  }) async {
    _pushUndoState();
    final isSyntheticVisitor =
        member.isVisitor || member.id.startsWith('visitor_');

    final updatedRecords = _currentSession.records.where((r) {
      if (isSyntheticVisitor) {
        return r.attendee != member.displayName;
      } else {
        return r.memberId != member.id && r.attendee != member.displayName;
      }
    }).toList();

    final updatedExcluded = List<String>.from(_currentSession.excludedMemberIds);
    if (!isSyntheticVisitor &&
        member.id.isNotEmpty &&
        !updatedExcluded.contains(member.id)) {
      updatedExcluded.add(member.id);
    }

    _sessionMembers.removeWhere((m) {
      if (isSyntheticVisitor) {
        return m.displayName == member.displayName;
      } else {
        return m.id == member.id && m.displayName == member.displayName;
      }
    });

    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      excludedMemberIds: updatedExcluded,
      updatedAt: DateTime.now(),
    );

    _currentSession = updatedSession;
    _updateTouchedTracking(_currentSession);
    notifyListeners();
    await _enqueueSave(_currentSession, actor: actor);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Undo & Rollback
  // ─────────────────────────────────────────────────────────────────────────

  void _pushUndoState() {
    _undoStack.add(_currentSession);
    if (_undoStack.length > _maxUndoDepth) {
      _undoStack.removeAt(0);
    }
  }

  /// Undoes the last session marking action, rolling back the in-memory state
  /// and persisting the restored snapshot.
  Future<Session?> undo({String? actor}) async {
    if (_undoStack.isEmpty) return null;

    final previousSession = _undoStack.removeLast();
    _currentSession = previousSession;
    _updateTouchedTracking(_currentSession);
    notifyListeners();
    await _enqueueSave(_currentSession, actor: actor);
    return _currentSession;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Persistence Serialization & Teardown
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _enqueueSave(Session session, {String? actor}) {
    final saveActor = actor ?? _defaultActor;
    final saveFuture = _saveQueue.then((_) async {
      try {
        final saved = await _sessionRepository.saveSnapshot(
          session,
          actor: saveActor,
        );
        if (saved.id == _currentSession.id &&
            saved.currentVersion >= _currentSession.currentVersion) {
          _currentSession = _currentSession.copyWith(
            currentVersion: saved.currentVersion,
          );
        }
      } catch (e, st) {
        _log.warning('Failed to save session snapshot: $e\n$st');
        _saveErrorController.add(e);
      }
    });
    _saveQueue = saveFuture;
    return saveFuture;
  }

  /// Drains all in-flight background saves.
  Future<void> drain() => _saveQueue;

  /// Cancels and discards the active session cleanly, ensuring any in-flight
  /// saves are drained before deleting the session record so orphaned writes
  /// never resurrect it.
  Future<void> discardSession({String actor = 'System (Cleanup)'}) async {
    await drain();
    await _sessionRepository.deleteSession(_currentSession.id, actor: actor);
  }

  /// Swaps in a newer session version from remote sync if available.
  void syncRemoteSession(Session newer) {
    if (newer.currentVersion > _currentSession.currentVersion ||
        (newer.currentVersion == _currentSession.currentVersion &&
            newer.updatedAt.isAfter(_currentSession.updatedAt))) {
      _currentSession = newer;
      _updateTouchedTracking(_currentSession);
      notifyListeners();
    }
  }

  /// Updates available families context (e.g. from attendance repository stream).
  void updateFamilies(List<Family> families) {
    _allFamilies = List.from(families);
    notifyListeners();
  }

  /// Updates event context (e.g. from event repository stream).
  void updateEvent(Event event) {
    _event = event;
    notifyListeners();
  }

  /// Updates member list context.
  void updateMembers(List<Member> members) {
    for (final m in members) {
      if (!_sessionMembers.any((existing) =>
          (m.id.isNotEmpty && existing.id == m.id) ||
          (m.id.isEmpty && existing.displayName == m.displayName))) {
        _sessionMembers.add(m);
      }
    }
    notifyListeners();
  }

  void _snapshotBaseline(Session session) {
    _baselineRecords = List.unmodifiable(session.records);
    _baselineStatus.clear();
    for (final r in session.records) {
      final cleanId = cleanMemberId(r.memberId);
      final key = cleanId ?? r.attendee;
      _baselineStatus[key] = r.status;
    }
  }

  void _updateTouchedTracking(Session session) {
    _touchedMemberIds.clear();
    _touchedMemberNames.clear();
    for (final r in session.records) {
      if (r.recordedBy != 'System (Preseed)') {
        final cleanId = cleanMemberId(r.memberId);
        if (cleanId != null) {
          _touchedMemberIds.add(cleanId);
        }
        _touchedMemberNames.add(r.attendee);
      }
    }
  }

  @override
  void dispose() {
    _membersSub?.cancel();
    _eventsSub?.cancel();
    _saveErrorController.close();
    super.dispose();
  }
}
