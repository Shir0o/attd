import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../../../../data/session.dart';
import '../../../../data/session_repository.dart';
import '../data/attendance_repository.dart';
import '../../hub/data/event_repository.dart';
import '../../hub/domain/event.dart';
import '../../settings/data/cisa_sync_service.dart';
import '../../settings/data/drive_service.dart';
import '../domain/attendance_marking_session.dart';
import '../models/family.dart';
import '../models/member.dart';
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
    this.markingSession,
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
  final AttendanceMarkingSession? markingSession;

  @override
  State<SessionSummaryPage> createState() => _SessionSummaryPageState();
}

class _SessionSummaryPageState extends State<SessionSummaryPage> {
  late Session _currentSession;
  late AttendanceMarkingSession _markingSession;
  late bool _ownsMarkingSession;
  late final CisaSyncService _cisaSyncService;
  bool _isSyncingCisa = false;
  List<Member> _allMembers = [];
  List<Family> _allFamilies = [];
  Event? _currentEvent;
  StreamSubscription? _membersSubscription;
  StreamSubscription? _eventsSubscription;

  void _onMarkingSessionChanged() {
    if (mounted) {
      setState(() {
        _currentSession = _markingSession.session;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session;
    _currentEvent = widget.event;
    _cisaSyncService = widget.cisaSyncService ?? CisaSyncService();
    if (widget.markingSession != null) {
      _markingSession = widget.markingSession!;
      _ownsMarkingSession = false;
    } else {
      _markingSession = AttendanceMarkingSession(
        session: widget.session,
        baseMembers: widget.members,
        families: widget.families,
        event: widget.event,
        sessionRepository: widget.sessionRepository,
        attendanceRepository: widget.attendanceRepository,
        eventRepository: widget.eventRepository,
      );
      _ownsMarkingSession = true;
    }
    _markingSession.addListener(_onMarkingSessionChanged);
    debugPrint(
        'DEBUG: SessionSummaryPage.initState: session=${_currentSession.id}, title=${_currentSession.title}');
    _refreshLatest();
    _subscribeToMembers();
    _subscribeToEvents();
  }

  @override
  void dispose() {
    _markingSession.removeListener(_onMarkingSessionChanged);
    if (_ownsMarkingSession) {
      _markingSession.dispose();
    }
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
        _markingSession.updateFamilies(families);
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
          _markingSession.updateEvent(e);
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
    if (widget.markingSession != null &&
        widget.markingSession != oldWidget.markingSession) {
      oldWidget.markingSession?.removeListener(_onMarkingSessionChanged);
      _markingSession = widget.markingSession!;
      _markingSession.addListener(_onMarkingSessionChanged);
      _currentSession = _markingSession.session;
    } else if (widget.session.currentVersion > _currentSession.currentVersion ||
        (widget.session.currentVersion == _currentSession.currentVersion &&
            widget.session.updatedAt.isAfter(_currentSession.updatedAt))) {
      _markingSession.syncRemoteSession(widget.session);
      setState(() {
        _currentSession = _markingSession.session;
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
      if (widget.event != null) {
        _markingSession.updateEvent(widget.event!);
      }
      _subscribeToEvents();
    }
  }

  Future<void> _addAttendee(
    String name,
    bool isPresent,
    bool isGuest,
    Member? existingMember,
  ) async {
    final resolved = await _markingSession.addAttendee(
      name,
      isPresent: isPresent,
      isGuest: isGuest,
      existingMember: existingMember,
      actor: 'User',
    );
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
    _markingSession.syncRemoteSession(latest);
  }

  Future<void> _toggleAttendance(Member member, bool isPresent) async {
    await _markingSession.toggleMember(member, isPresent, actor: 'User');
  }

  Future<void> _toggleFamilyAttendance(Family family, bool isPresent) async {
    await _markingSession.markFamily(family, isPresent, actor: 'User');
  }

  Future<void> _markAllAttendance(BulkMarkChoice choice) async {
    final allMembers = _displayFamilies.expand((f) => f.members).toList();

    final String summary;
    if (choice == BulkMarkChoice.smart) {
      final recentSessions = await _loadRecentSessions();
      final result = await _markingSession.markAllSmart(
        members: allMembers,
        recentSessions: recentSessions,
        actor: 'User',
      );
      summary = result.resolved == 0
          ? 'No members had enough history for a smart guess.'
          : 'Applied smart defaults to ${result.resolved} '
              '${result.resolved == 1 ? 'member' : 'members'}.';
    } else {
      final present = choice == BulkMarkChoice.present;
      await _markingSession.markAll(
        allMembers,
        present: present,
        actor: 'User',
      );
      summary = 'Marked ${allMembers.length} '
          '${allMembers.length == 1 ? 'member' : 'members'} '
          '${present ? 'present' : 'absent'}.';
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
          onPressed: () => _markingSession.undo(actor: 'User'),
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

  Future<void> _toggleLate(Member member) async {
    await _markingSession.toggleLate(member, actor: 'User');
  }

  Future<void> _editMemberName(Member member) async {
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

    await _markingSession.editMemberName(member, newName, actor: 'User');
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

    await _markingSession.removeMemberFromSession(member, actor: 'User');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${member.displayName} removed from this report'),
        ),
      );
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
        await _markingSession.discardSession(actor: 'You');

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
        disableAnimations: widget.disableAnimations,
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
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy')
                        .format(_currentSession.sessionDate),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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
