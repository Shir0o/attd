import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../../../../data/session.dart';
import '../../../../data/session_record.dart';
import '../../../../data/session_repository.dart';
import '../data/attendance_repository.dart';
import '../../hub/data/event_repository.dart';
import '../../hub/domain/event.dart';
import '../../settings/data/cisa_sync_service.dart';
import '../../settings/data/drive_service.dart';
import '../models/attendance_status.dart';
import '../models/family.dart';
import '../models/member.dart';
import '../utils/bulk_attendance.dart';
import '../utils/session_roster_utils.dart';
import 'add_guest_sheet.dart';
import 'attendance_roster_list.dart';
import 'mark_everyone_sheet.dart';

class SessionSummaryPage extends StatefulWidget {
  const SessionSummaryPage({
    super.key,
    required this.session,
    required this.members,
    this.families,
    required this.sessionRepository,
    this.attendanceRepository,
    this.eventRepository,
    this.event,
    this.driveService,
    this.cisaSyncService,
    this.disableAnimations = false,
  });

  final Session session;
  final List<Member> members;
  final List<Family>? families;
  final SessionRepository sessionRepository;
  final AttendanceRepository? attendanceRepository;
  final EventRepository? eventRepository;
  final Event? event;
  final DriveService? driveService;
  final CisaSyncService? cisaSyncService;
  final bool disableAnimations;

  @override
  State<SessionSummaryPage> createState() => _SessionSummaryPageState();
}

class _SessionSummaryPageState extends State<SessionSummaryPage> {
  late Session _currentSession;
  late final CisaSyncService _cisaSyncService;
  bool _isSyncingCisa = false;
  List<Member> _allMembers = [];
  List<Family> _allFamilies = [];
  Event? _currentEvent;
  StreamSubscription? _membersSubscription;
  StreamSubscription? _eventsSubscription;

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session;
    _currentEvent = widget.event;
    _cisaSyncService = widget.cisaSyncService ?? CisaSyncService();
    debugPrint(
        'DEBUG: SessionSummaryPage.initState: session=${_currentSession.id}, title=${_currentSession.title}');
    _refreshLatest();
    _subscribeToMembers();
    _subscribeToEvents();
  }

  @override
  void dispose() {
    _membersSubscription?.cancel();
    _eventsSubscription?.cancel();
    if (widget.cisaSyncService == null) {
      _cisaSyncService.close();
    }
    super.dispose();
  }

  Future<void> _syncToCisa() async {
    if (_isSyncingCisa) return;
    setState(() => _isSyncingCisa = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await _cisaSyncService.syncSession(
        session: _currentSession,
        event: _currentEvent,
      );
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      if (result.success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Synced to CISA Gathering successfully!'),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Failed to sync to CISA.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingCisa = false);
      }
    }
  }

  void _subscribeToMembers() {
    _membersSubscription =
        widget.attendanceRepository?.streamFamilies().listen((families) {
      if (mounted) {
        setState(() {
          _allFamilies = families;
          _allMembers = families.expand((f) => f.members).toList();
        });
      }
    });
  }

  void _subscribeToEvents() {
    final eventId = widget.event?.id;
    final repo = widget.eventRepository;
    if (eventId == null || repo == null) return;
    _eventsSubscription = repo.streamEvents().listen((events) {
      if (!mounted) return;
      for (final e in events) {
        if (e.id == eventId) {
          setState(() => _currentEvent = e);
          return;
        }
      }
    });
  }

  List<Member> get _displayMembers {
    final ev = _currentEvent;
    if (ev != null && _allMembers.isNotEmpty) {
      final ids = ev.memberIds.toSet();
      return _allMembers.where((m) => ids.contains(m.id)).toList();
    }
    return widget.members;
  }

  List<Family> get _displayFamilies {
    if (widget.families != null && widget.families!.isNotEmpty) {
      return widget.families!;
    }
    final ev = _currentEvent;
    if (_allFamilies.isNotEmpty) {
      final ids =
          ev?.memberIds.toSet() ?? widget.members.map((m) => m.id).toSet();
      final result = <Family>[];
      for (final f in _allFamilies) {
        final filtered = f.members.where((m) => ids.contains(m.id)).toList();
        if (filtered.isEmpty) continue;
        result.add(f.copyWith(members: filtered));
      }
      if (result.isNotEmpty) return result;
    }
    return [
      Family(
        id: '_synthetic_all',
        displayName: 'All members',
        members: _displayMembers,
      ),
    ];
  }

  @override
  void didUpdateWidget(covariant SessionSummaryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session.currentVersion > _currentSession.currentVersion ||
        (widget.session.currentVersion == _currentSession.currentVersion &&
            widget.session.updatedAt.isAfter(_currentSession.updatedAt))) {
      setState(() {
        _currentSession = widget.session;
      });
    }

    if (widget.attendanceRepository != oldWidget.attendanceRepository) {
      _membersSubscription?.cancel();
      _subscribeToMembers();
    }

    if (widget.eventRepository != oldWidget.eventRepository ||
        widget.event?.id != oldWidget.event?.id) {
      _eventsSubscription?.cancel();
      _eventsSubscription = null;
      _currentEvent = widget.event;
      _subscribeToEvents();
    }
  }

  Future<void> _ensureMemberInEvent(String memberId) async {
    final ev = _currentEvent;
    final repo = widget.eventRepository;
    if (ev == null || repo == null) return;
    if (ev.memberIds.contains(memberId)) return;

    final updated = ev.copyWith(
      memberIds: [...ev.memberIds, memberId],
      updatedAt: DateTime.now(),
    );
    setState(() => _currentEvent = updated);
    try {
      await repo.updateEvent(updated);
    } catch (e) {
      debugPrint('Error adding member to event: $e');
    }
  }

  Future<Member?> _createGlobalMember(String name) async {
    final repo = widget.attendanceRepository;
    if (repo == null) return null;
    try {
      final family = await repo.addFamily(name, isAutoSingleton: true);
      final member = Member(id: const Uuid().v4(), displayName: name);
      await repo.addMember(family.id, member);
      return member;
    } catch (e) {
      debugPrint('Error creating global member: $e');
      return null;
    }
  }

  Future<void> _addAttendee(
    String name,
    bool isPresent,
    bool isGuest,
    Member? existingMember,
  ) async {
    Member resolved;
    if (existingMember != null) {
      resolved = existingMember;
      await _ensureMemberInEvent(existingMember.id);
    } else if (!isGuest && name.trim().isNotEmpty) {
      final trimmed = name.trim();
      final created = await _createGlobalMember(trimmed);
      if (created != null) {
        resolved = created;
        await _ensureMemberInEvent(created.id);
      } else {
        resolved = Member(id: '', displayName: trimmed, isVisitor: true);
      }
    } else {
      resolved = Member(id: '', displayName: name, isVisitor: true);
    }
    await _toggleAttendance(resolved, isPresent);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${resolved.displayName} marked ${isPresent ? "present" : "absent"}',
          ),
        ),
      );
    }
  }

  // The page renders immediately from the session passed in by the caller.
  // This silently checks for a newer version (e.g. synced from another device)
  // and swaps it in if found — no skeleton, no blocking load.
  Future<void> _refreshLatest() async {
    final latest = await widget.sessionRepository.findSessionById(
      _currentSession.id,
    );

    if (!mounted || latest == null) return;

    final isNewer = latest.currentVersion > _currentSession.currentVersion ||
        (latest.currentVersion == _currentSession.currentVersion &&
            latest.updatedAt.isAfter(_currentSession.updatedAt));
    if (isNewer) {
      setState(() {
        _currentSession = latest;
      });
    }
  }

  Future<void> _toggleAttendance(Member member, bool isPresent) async {
    final status =
        isPresent ? AttendanceStatus.present : AttendanceStatus.absent;

    final memberIdForRecord =
        (member.isVisitor || member.id.trim().isEmpty) ? null : member.id;

    final newRecord = SessionRecord(
      memberId: memberIdForRecord,
      attendee: member.displayName,
      status: status,
      recordedAt: DateTime.now(),
      recordedBy: 'User',
    );

    final updatedRecords = List<SessionRecord>.from(_currentSession.records);
    updatedRecords.removeWhere((r) =>
        (memberIdForRecord != null && r.memberId == memberIdForRecord) ||
        (memberIdForRecord == null &&
            r.memberId == null &&
            r.attendee == member.displayName));
    updatedRecords.add(newRecord);

    final updatedExcluded = List<String>.from(_currentSession.excludedMemberIds);
    if (memberIdForRecord != null) {
      updatedExcluded.remove(memberIdForRecord);
    }

    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      excludedMemberIds: updatedExcluded,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _currentSession = updatedSession;
    });

    try {
      final saved = await widget.sessionRepository
          .saveSnapshot(updatedSession, actor: 'User');
      if (mounted) {
        setState(() {
          _currentSession = saved;
        });
      }
    } catch (e) {
      debugPrint('Error updating session record: $e');
    }
  }

  Future<void> _toggleFamilyAttendance(Family family, bool isPresent) async {
    // Batch every family member into a single saveSnapshot call — much
    // cheaper than one write per member.
    final now = DateTime.now();
    final status =
        isPresent ? AttendanceStatus.present : AttendanceStatus.absent;
    final updatedRecords = List<SessionRecord>.from(_currentSession.records);
    for (final m in family.members) {
      final mid = (m.isVisitor || m.id.trim().isEmpty) ? null : m.id;
      updatedRecords.removeWhere((r) =>
          (mid != null && r.memberId == mid) ||
          (mid == null && r.memberId == null && r.attendee == m.displayName));
      updatedRecords.add(SessionRecord(
        memberId: mid,
        attendee: m.displayName,
        status: status,
        recordedAt: now,
        recordedBy: 'User',
      ));
    }
    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      updatedAt: now,
    );
    setState(() {
      _currentSession = updatedSession;
    });
    try {
      await widget.sessionRepository
          .saveSnapshot(updatedSession, actor: 'User');
    } catch (e) {
      debugPrint('Error updating session records: $e');
    }
  }

  Future<void> _markAllAttendance(BulkMarkChoice choice) async {
    final previousRecords = List<SessionRecord>.from(_currentSession.records);
    final now = DateTime.now();
    final allMembers = _displayFamilies.expand((f) => f.members).toList();

    final List<SessionRecord> updatedRecords;
    final String summary;
    if (choice == BulkMarkChoice.smart) {
      final recentSessions = await _loadRecentSessions();
      final result = applyBulkSmartRecords(
        previousRecords: previousRecords,
        members: allMembers,
        recentSessions: recentSessions,
        recordedAt: now,
      );
      updatedRecords = result.records;
      summary = result.resolved == 0
          ? 'No members had enough history for a smart guess.'
          : 'Applied smart defaults to ${result.resolved} '
              '${result.resolved == 1 ? 'member' : 'members'}.';
    } else {
      final present = choice == BulkMarkChoice.present;
      updatedRecords = applyBulkRecords(
        previousRecords: previousRecords,
        members: allMembers,
        present: present,
        recordedAt: now,
      );
      summary = 'Marked ${allMembers.length} '
          '${allMembers.length == 1 ? 'member' : 'members'} '
          '${present ? 'present' : 'absent'}.';
    }

    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      updatedAt: now,
    );
    setState(() => _currentSession = updatedSession);
    try {
      await widget.sessionRepository
          .saveSnapshot(updatedSession, actor: 'User');
    } catch (e) {
      debugPrint('Error bulk-updating session: $e');
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(summary),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _restoreRecords(previousRecords),
        ),
      ),
    );
  }

  /// Loads past sessions (newest-first, excluding the current one) for the
  /// smart-defaults bulk action.
  Future<List<Session>> _loadRecentSessions() async {
    try {
      final all = await widget.sessionRepository.loadSessions();
      final sorted = all.toList()
        ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
      return sorted.where((s) => s.id != _currentSession.id).toList();
    } catch (e) {
      debugPrint('Error loading session history for smart defaults: $e');
      return const [];
    }
  }

  Future<void> _restoreRecords(List<SessionRecord> previousRecords) async {
    final restored = _currentSession.copyWith(
      records: previousRecords,
      updatedAt: DateTime.now(),
    );
    setState(() => _currentSession = restored);
    try {
      await widget.sessionRepository.saveSnapshot(restored, actor: 'User');
    } catch (e) {
      debugPrint('Error restoring session: $e');
    }
  }

  /// Flags [member] present-but-late (or clears the flag when they are
  /// already late) by rebuilding their record through the same snapshot path
  /// as the present/absent toggle.
  ///
  /// Resolves the record the way [SessionRoster] reads it — by memberId when
  /// the member has one, falling back to the visitor-name index — so a
  /// present record stored without a memberId (a guest whose name matches a
  /// roster member, or legacy/Drive-restored data) is still flipped. Without
  /// the fallback the dot would be a silent no-op for exactly the rows that
  /// show it.
  Future<void> _toggleLate(Member member) async {
    final hasId = !member.isVisitor && member.id.trim().isNotEmpty;

    final updatedRecords = List<SessionRecord>.from(_currentSession.records);

    // Resolve the record the way SessionRoster reads it: by memberId when a
    // member-keyed record exists, else the visitor-name index. A present
    // record stored without a memberId (a guest whose name matches a roster
    // member, or legacy/Drive-restored data) is still flipped — without this
    // fallback the dot would be a silent no-op for exactly those rows.
    SessionRecord? target;
    var targetIndex = -1;
    for (var i = 0; i < updatedRecords.length; i++) {
      final r = updatedRecords[i];
      final byId = hasId && r.memberId == member.id;
      final byName = r.memberId == null && r.attendee == member.displayName;
      if (byId || byName) {
        target = r;
        targetIndex = i;
        if (byId) break; // member-keyed record wins over a name match
      }
    }
    if (target == null || targetIndex < 0) return;

    updatedRecords[targetIndex] = target.copyWith(
      isLate: !target.isLate,
      recordedAt: DateTime.now(),
      recordedBy: 'User',
    );

    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      updatedAt: DateTime.now(),
    );
    setState(() => _currentSession = updatedSession);
    try {
      await widget.sessionRepository
          .saveSnapshot(updatedSession, actor: 'User');
    } catch (e) {
      debugPrint('Error toggling late flag: $e');
    }
  }

  Future<void> _editMemberName(Member member) async {
    final isVisitor = member.isVisitor;
    final controller = TextEditingController(text: member.displayName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            Text(
              'This corrects the name in this report only. It will not change '
              'your global roster or other sessions.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == member.displayName) {
      return;
    }

    final updatedRecords = _currentSession.records.map((r) {
      final matchesById = !isVisitor && r.memberId == member.id;
      final matchesByName =
          isVisitor && r.attendee == member.displayName && r.memberId == null;

      if (matchesById || matchesByName) {
        return r.copyWith(attendee: newName);
      }
      return r;
    }).toList();

    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _currentSession = updatedSession;
    });

    try {
      await widget.sessionRepository
          .saveSnapshot(updatedSession, actor: 'User');
    } catch (e) {
      debugPrint('Error updating session record: $e');
    }
  }

  Future<void> _removeMemberFromSession(Member member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Report'),
        content: Text(
          'Are you sure you want to remove "${member.displayName}" from "${_currentSession.title}" on ${DateFormat('MMM d, yyyy').format(_currentSession.sessionDate)}?\n\nThis will not delete them from your global roster or other sessions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final updatedRecords = _currentSession.records.where((r) {
      if (member.isVisitor) {
        return r.memberId != null || r.attendee != member.displayName;
      } else {
        return r.memberId != member.id;
      }
    }).toList();

    List<String> updatedExcluded =
        List<String>.from(_currentSession.excludedMemberIds);
    if (!member.isVisitor && !updatedExcluded.contains(member.id)) {
      updatedExcluded.add(member.id);
    }

    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      excludedMemberIds: updatedExcluded,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _currentSession = updatedSession;
    });

    try {
      await widget.sessionRepository
          .saveSnapshot(updatedSession, actor: 'User');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${member.displayName} removed from this report')),
        );
      }
    } catch (e) {
      debugPrint('Error removing member from session: $e');
    }
  }

  void _showHistoryInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history, color: Colors.blue),
            SizedBox(width: 12),
            Text('Historical Snapshot'),
          ],
        ),
        content: const Text(
          'This report is a historical snapshot. It shows the names and status of people exactly as they were recorded on this day.\n\nChanges made in the global "Manage Members" settings will not affect this past report to ensure data integrity.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text(
          'Are you sure you want to delete "${_currentSession.title}" for ${DateFormat('yyyy-MM-dd').format(_currentSession.sessionDate)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      try {
        await widget.sessionRepository.deleteSession(
          _currentSession.id,
          actor: 'You',
        );

        navigator.pop(null);
        messenger.showSnackBar(
          const SnackBar(content: Text('Session deleted')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error deleting session: $e')),
        );
      }
    }
  }

  void _showAddMemberSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddMemberSheet(
        onAdd: (name, isPresent, isGuest, existingMember) {
          _addAttendee(name, isPresent, isGuest, existingMember);
        },
        availableMembers: _allMembers,
        families: _allFamilies.isNotEmpty
            ? _allFamilies
            : (widget.families ?? const []),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final roster = SessionRoster(_currentSession, _displayMembers);
    final allDisplayMembers = roster.sortedMembers;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.95),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(_currentSession),
        ),
        actions: [
          IconButton(
            key: const ValueKey('sync_cisa_button'),
            tooltip: 'Sync to CISA Gathering',
            onPressed: _isSyncingCisa ? null : _syncToCisa,
            icon: _isSyncingCisa
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            color: colorScheme.primary,
          ),
          IconButton(
            tooltip: 'View data policy',
            onPressed: _showHistoryInfo,
            icon: const Icon(Icons.info_outline),
            color: colorScheme.onSurfaceVariant,
          ),
          IconButton(
            tooltip: 'Add attendee',
            onPressed: _showAddMemberSheet,
            icon: const Icon(Icons.person_add),
            color: colorScheme.primary,
          ),
          IconButton(
            tooltip: 'Delete session',
            onPressed: _deleteSession,
            icon: Icon(
              Icons.delete_outline,
              color: colorScheme.error,
            ),
          ),
        ],
      ),
      body: RepaintBoundary(
        child: Column(
          key: const ValueKey('content'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConvEyebrow(
                    'SAVED · ${DateFormat('MMM d, h:mm a').format(_currentSession.updatedAt)}',
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentSession.title.trim(),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          'Attendance Roster',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${allDisplayMembers.length} Total',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: AttendanceRosterList(
                session: _currentSession,
                families: _displayFamilies,
                onToggle: _toggleAttendance,
                onFamilyToggle: _toggleFamilyAttendance,
                onMarkAll: _markAllAttendance,
                onToggleLate: _toggleLate,
                onEdit: _editMemberName,
                onRemove: _removeMemberFromSession,
                initialGrouping: RosterGrouping.byStatus,
                disableAnimations: widget.disableAnimations,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
