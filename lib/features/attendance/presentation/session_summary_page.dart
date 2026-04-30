import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_theme.dart';
import '../../../../data/session.dart';
import '../../../../data/session_record.dart';
import '../../../../data/session_repository.dart';
import '../data/attendance_repository.dart';
import '../../hub/data/event_repository.dart';
import '../../hub/domain/event.dart';
import '../../settings/data/drive_service.dart';
import '../models/attendance_status.dart';
import '../models/member.dart';
import '../utils/session_roster_utils.dart';
import 'add_guest_sheet.dart';

class SessionSummaryPage extends StatefulWidget {
  const SessionSummaryPage({
    super.key,
    required this.session,
    required this.members,
    required this.sessionRepository,
    this.attendanceRepository,
    this.eventRepository,
    this.event,
    this.driveService,
    this.disableAnimations = false,
  });

  final Session session;
  final List<Member> members;
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
        // Synchronous update for tests
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

    final presentMembers = <Member>[];
    final absentMembers = <Member>[];

    for (final member in allDisplayMembers) {
      final status = roster.getStatus(member);

      if (status == AttendanceStatus.present) {
        presentMembers.add(member);
      } else {
        absentMembers.add(member);
      }
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          RepaintBoundary(
            child: AnimatedSwitcher(
              duration: widget.disableAnimations ? Duration.zero : const Duration(milliseconds: 600),
              child: _isLoading
                  ? _buildSkeleton(context)
                  : CustomScrollView(
                      key: const ValueKey('content'),
                      slivers: [
                        // Header
                        SliverAppBar(
                          backgroundColor: colorScheme.surface.withValues(
                            alpha: 0.95,
                          ),
                          surfaceTintColor: Colors.transparent,
                          pinned: true,
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            color: colorScheme.onSurface,
                            onPressed: () =>
                                Navigator.of(context).pop(_currentSession),
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

                        SliverToBoxAdapter(
                          child: Padding(
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
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.15,
                                        ),
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
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'PRESENT',
                                            style: TextStyle(
                                              color: colorScheme
                                                  .onPrimaryContainer,
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
                                              '${presentMembers.length}',
                                              style: TextStyle(
                                                color: colorScheme.primary,
                                                fontSize: 32,
                                                fontWeight: FontWeight.w500,
                                                height: 1.0,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        width: 1,
                                        height: 30,
                                        color: colorScheme.onPrimaryContainer
                                            .withValues(alpha: 0.2),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'ABSENT',
                                            style: TextStyle(
                                              color: colorScheme
                                                  .onPrimaryContainer,
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
                                              '${absentMembers.length}',
                                              style: TextStyle(
                                                color: colorScheme.error,
                                                fontSize: 32,
                                                fontWeight: FontWeight.w500,
                                                height: 1.0,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                        ),

                        SliverToBoxAdapter(
                          child: _SectionHeader(
                            title: 'Marked Present',
                            color: colorScheme.primary,
                          ),
                        ),

                        SliverList(
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final member = presentMembers[index];
                            return _MemberListItem(
                              member: member,
                              isPresent: true,
                              onToggle: (value) =>
                                  _toggleAttendance(member, value),
                              onEdit: () => _editMemberName(member),
                              onRemove: () => _removeMemberFromSession(member),
                            );
                          }, childCount: presentMembers.length),
                        ),

                        SliverToBoxAdapter(
                          child: _SectionHeader(
                            title: 'Marked Absent',
                            color: colorScheme.error,
                          ),
                        ),

                        SliverList(
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final member = absentMembers[index];
                            return _MemberListItem(
                              member: member,
                              isPresent: false,
                              onToggle: (value) =>
                                  _toggleAttendance(member, value),
                              onEdit: () => _editMemberName(member),
                              onRemove: () => _removeMemberFromSession(member),
                            );
                          }, childCount: absentMembers.length),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: colorScheme.surface,
          pinned: true,
          title: AppShimmer(
            width: 150,
            height: 24,
            borderRadius: BorderRadius.circular(12),
            disableAnimations: widget.disableAnimations,
          ),
          centerTitle: true,
        ),
        SliverToBoxAdapter(
          child: Padding(
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
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: AppShimmer(
                width: double.infinity,
                height: 72,
                borderRadius: BorderRadius.circular(16),
                disableAnimations: widget.disableAnimations,
              ),
            ),
            childCount: 5,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberListItem extends StatelessWidget {
  final Member member;
  final bool isPresent;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _MemberListItem({
    required this.member,
    required this.isPresent,
    required this.onToggle,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Dismissible(
        key: ValueKey('dismiss_${member.id}_${member.displayName}'),
        direction: DismissDirection.horizontal,
        background: _buildSwipeBackground(
          context,
          'Edit Name',
          colorScheme.secondary,
          Icons.edit_outlined,
          true,
        ),
        secondaryBackground: _buildSwipeBackground(
          context,
          'Remove',
          colorScheme.error,
          Icons.remove_circle_outline,
          false,
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            onEdit();
          } else {
            onRemove();
          }
          return false; // Handle state externally
        },
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: ListTile(
            visualDensity: VisualDensity.compact,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: isPresent
                  ? colorScheme.primary.withValues(alpha: 0.1)
                  : colorScheme.error.withValues(alpha: 0.1),
              child: Text(
                member.displayName.isNotEmpty
                    ? member.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: isPresent ? colorScheme.primary : colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              member.displayName,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: member.isVisitor
                ? Text(
                    'Visitor',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: isPresent,
                    onChanged: onToggle,
                    activeColor: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeBackground(
    BuildContext context,
    String label,
    Color color,
    IconData icon,
    bool isStart,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: isStart ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isStart
            ? [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]
            : [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(icon, color: Colors.white),
              ],
      ),
    );
  }
}
