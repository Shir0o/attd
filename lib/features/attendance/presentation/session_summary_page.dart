import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../../data/session.dart';
import '../../../../data/session_record.dart';
import '../../../../data/session_repository.dart';
import '../data/attendance_repository.dart';
import '../../hub/data/event_repository.dart';
import '../../hub/domain/event.dart';
import '../../settings/data/drive_service.dart';
import '../models/attendance_status.dart';
import '../models/family.dart';
import '../models/member.dart';
import '../utils/session_roster_utils.dart';
import 'add_guest_sheet.dart';
import 'attendance_roster_list.dart';

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
  final bool disableAnimations;

  @override
  State<SessionSummaryPage> createState() => _SessionSummaryPageState();
}

class _SessionSummaryPageState extends State<SessionSummaryPage> {
  late Session _currentSession;
  bool _isLoading = true;
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
    debugPrint('DEBUG: SessionSummaryPage.initState: session=${_currentSession.id}, title=${_currentSession.title}');
    _refreshLatest();
    _subscribeToMembers();
    _subscribeToEvents();
  }

  @override
  void dispose() {
    _membersSubscription?.cancel();
    _eventsSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToMembers() {
    _membersSubscription = widget.attendanceRepository?.streamFamilies().listen((families) {
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
      final ids = ev?.memberIds.toSet() ??
          widget.members.map((m) => m.id).toSet();
      final result = <Family>[];
      for (final f in _allFamilies) {
        final filtered =
            f.members.where((m) => ids.contains(m.id)).toList();
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
      final family = await repo.addFamily(name);
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
  }

  Future<void> _refreshLatest() async {
    final startTime = DateTime.now();

    final latestFuture = widget.sessionRepository.findSessionById(
      _currentSession.id,
    );

    final latest = await latestFuture;

    if (mounted) {
      if (latest != null) {
        final isNewer = latest.currentVersion > _currentSession.currentVersion ||
            (latest.currentVersion == _currentSession.currentVersion &&
                latest.updatedAt.isAfter(_currentSession.updatedAt));
        if (isNewer) {
          setState(() {
            _currentSession = latest;
          });
        }
      }

      if (widget.disableAnimations) {
        setState(() => _isLoading = false);
        debugPrint('DEBUG: SessionSummaryPage loading finished immediately (sync)');
      } else {
        final elapsed = DateTime.now().difference(startTime);
        const minDuration = Duration(milliseconds: 800);
        if (elapsed < minDuration) {
          Future.delayed(minDuration - elapsed, () {
            if (mounted) {
              setState(() => _isLoading = false);
              debugPrint('DEBUG: SessionSummaryPage loading finished after delay');
            }
          });
        } else {
          setState(() => _isLoading = false);
          debugPrint('DEBUG: SessionSummaryPage loading finished after long refresh');
        }
      }
    }
  }

  Future<void> _toggleAttendance(Member member, bool isPresent) async {
    final status = isPresent ? AttendanceStatus.present : AttendanceStatus.absent;

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
          r.attendee == member.displayName)
    );
    updatedRecords.add(newRecord);

    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _currentSession = updatedSession;
    });

    try {
      await widget.sessionRepository.saveSnapshot(updatedSession, actor: 'User');
    } catch (e) {
      debugPrint('Error updating session record: $e');
    }
  }

  Future<void> _toggleFamilyAttendance(Family family, bool isPresent) async {
    for (final m in family.members) {
      await _toggleAttendance(m, isPresent);
    }
  }

  Future<void> _editMemberName(Member member) async {
    final isVisitor = member.isVisitor;
    final controller = TextEditingController(text: member.displayName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Member'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
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

    if (newName == null || newName.isEmpty || newName == member.displayName) return;

    final updatedRecords = _currentSession.records.map((r) {
      final matchesById = !isVisitor && r.memberId == member.id;
      final matchesByName = isVisitor && r.attendee == member.displayName && r.memberId == null;

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
      await widget.sessionRepository.saveSnapshot(updatedSession, actor: 'User');
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

    List<String> updatedExcluded = List<String>.from(_currentSession.excludedMemberIds);
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
      await widget.sessionRepository.saveSnapshot(updatedSession, actor: 'User');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.displayName} removed from this report')),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final roster = SessionRoster(_currentSession, _displayMembers);
    final allDisplayMembers = roster.sortedMembers;

    int presentCount = 0;
    int absentCount = 0;
    for (final member in allDisplayMembers) {
      final status = roster.getStatus(member);
      if (status == AttendanceStatus.present) {
        presentCount++;
      } else {
        absentCount++;
      }
    }

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
        title: Text(
          _currentSession.title.trim(),
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
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
        child: AnimatedSwitcher(
          duration: widget.disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 600),
          child: _isLoading
              ? _buildSkeleton(context)
              : Column(
                  key: const ValueKey('content'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Session Date: ${DateFormat('MMMM d, yyyy').format(_currentSession.sessionDate)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _StatsCard(
                            presentCount: presentCount,
                            absentCount: absentCount,
                          ),
                          const SizedBox(height: 8),
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
                        onEdit: _editMemberName,
                        onRemove: _removeMemberFromSession,
                        initialGrouping: RosterGrouping.byStatus,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return ListView(
      key: const ValueKey('skeleton'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppShimmer(
                width: 200,
                height: 16,
                borderRadius: BorderRadius.circular(8),
                disableAnimations: widget.disableAnimations,
              ),
              const SizedBox(height: 12),
              AppShimmer(
                width: double.infinity,
                height: 140,
                borderRadius: BorderRadius.circular(24),
                disableAnimations: widget.disableAnimations,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppShimmer(
                    width: 180,
                    height: 32,
                    borderRadius: BorderRadius.circular(12),
                    disableAnimations: widget.disableAnimations,
                  ),
                  AppShimmer(
                    width: 80,
                    height: 20,
                    borderRadius: BorderRadius.circular(8),
                    disableAnimations: widget.disableAnimations,
                  ),
                ],
              ),
            ],
          ),
        ),
        for (int i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AppShimmer(
              width: double.infinity,
              height: 72,
              borderRadius: BorderRadius.circular(16),
              disableAnimations: widget.disableAnimations,
            ),
          ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.presentCount, required this.absentCount});

  final int presentCount;
  final int absentCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          _StatColumn(
            label: 'PRESENT',
            value: presentCount,
            valueColor: colorScheme.primary,
            labelColor: colorScheme.onPrimaryContainer,
          ),
          Container(
            width: 1,
            height: 30,
            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
          ),
          _StatColumn(
            label: 'ABSENT',
            value: absentCount,
            valueColor: colorScheme.error,
            labelColor: colorScheme.onPrimaryContainer,
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelColor,
  });

  final String label;
  final int value;
  final Color valueColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
          ),
          maxLines: 1,
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$value',
            style: TextStyle(
              color: valueColor,
              fontSize: 32,
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}
