import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../../data/session.dart';
import '../../../../data/session_record.dart';
import '../../../../data/session_repository.dart';
import '../data/attendance_repository.dart';
import '../../hub/data/event_repository.dart';
import '../../settings/data/drive_service.dart';
import '../models/attendance_status.dart';
import '../models/member.dart';
import '../models/family.dart';
import 'add_guest_sheet.dart';

class SessionSummaryPage extends StatefulWidget {
  const SessionSummaryPage({
    super.key,
    required this.session,
    required this.members,
    required this.sessionRepository,
    this.attendanceRepository,
    this.eventRepository,
    this.driveService,
  });

  final Session session;
  final List<Member> members;
  final SessionRepository sessionRepository;
  final AttendanceRepository? attendanceRepository;
  final EventRepository? eventRepository;
  final DriveService? driveService;

  @override
  State<SessionSummaryPage> createState() => _SessionSummaryPageState();
}

class _SessionSummaryPageState extends State<SessionSummaryPage> {
  late Session _currentSession;
  bool _isLoading = true;
  List<Member> _allMembers = [];
  StreamSubscription? _membersSubscription;

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session;
    _refreshLatest();
    _subscribeToMembers();
  }

  @override
  void dispose() {
    _membersSubscription?.cancel();
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
  }

  Future<void> _refreshLatest() async {
    final startTime = DateTime.now();
    
    final latestFuture = widget.sessionRepository.findSessionById(
      _currentSession.id,
    );

    final families = await widget.attendanceRepository?.fetchFamilies();

    final latest = await latestFuture;

    if (mounted) {
      setState(() {
        if (latest != null) {
          final isNewer = latest.currentVersion > _currentSession.currentVersion ||
              (latest.currentVersion == _currentSession.currentVersion &&
                  latest.updatedAt.isAfter(_currentSession.updatedAt));

          if (isNewer) {
            _currentSession = latest;
          }
        }
        if (families != null) {
          _allMembers = families.expand((f) => f.members).toList();
        }
      });
    }

    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(milliseconds: 800) - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showAddMemberSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => AddMemberSheet(
            availableMembers: _allMembers,
            onAdd: (name, isPresent, isGuest, existingMember) async {
              Member member;
              if (existingMember != null) {
                member = existingMember;
              } else if (!isGuest && widget.attendanceRepository != null) {
                // Add as regular member
                try {
                  final families =
                      await widget.attendanceRepository!.fetchFamilies();
                  Family targetFamily;
                  if (families.isEmpty) {
                    targetFamily =
                        await widget.attendanceRepository!.addFamily('General');
                  } else {
                    targetFamily = families.first;
                  }

                  final memberId =
                      DateTime.now().millisecondsSinceEpoch.toString();
                  member = Member(id: memberId, displayName: name);

                  await widget.attendanceRepository!.addMember(
                    targetFamily.id,
                    member,
                  );

                  // Tie to event
                  if (widget.session.eventId != null &&
                      widget.eventRepository != null) {
                    final event = await widget.eventRepository!.findEventById(
                      widget.session.eventId!,
                    );
                    if (event != null && !event.memberIds.contains(memberId)) {
                      await widget.eventRepository!.updateEvent(
                        event.copyWith(
                          memberIds: [...event.memberIds, memberId],
                        ),
                      );
                    }
                  }
                } catch (e) {
                  debugPrint('Error adding regular member in summary: $e');
                  // Fallback to visitor if error
                  member = Member(
                    id: 'visitor_${DateTime.now().microsecondsSinceEpoch}',
                    displayName: name,
                    isVisitor: true,
                  );
                }
              } else {
                // Add as guest/visitor
                member = Member(
                  id: 'visitor_${DateTime.now().microsecondsSinceEpoch}',
                  displayName: name,
                  isVisitor: true,
                );
              }

              // If it was an excluded member, un-exclude them
              if (!member.isVisitor && _currentSession.excludedMemberIds.contains(member.id)) {
                final updatedExcluded = _currentSession.excludedMemberIds
                    .where((id) => id != member.id)
                    .toList();
                _currentSession = _currentSession.copyWith(excludedMemberIds: updatedExcluded);
              }

              await _toggleAttendance(member, isPresent);

              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('${member.displayName} added')));
              }
            },
          ),
    );
  }

  Future<void> _toggleAttendance(Member member, bool isPresent) async {
    final status = isPresent
        ? AttendanceStatus.present
        : AttendanceStatus.absent;
    
    final newRecord = SessionRecord(
      memberId: member.id.startsWith('visitor_') ? null : member.id,
      attendee: member.displayName,
      status: status,
      recordedAt: DateTime.now(),
      recordedBy: 'User',
    );

    final updatedRecords = List<SessionRecord>.from(_currentSession.records);
    final existingIndex = updatedRecords.indexWhere(
      (r) => (r.memberId != null && r.memberId == member.id) || 
             (r.memberId == null && r.attendee == member.displayName),
    );
    if (existingIndex != -1) {
      updatedRecords[existingIndex] = newRecord;
    } else {
      updatedRecords.add(newRecord);
    }

    final updatedSession = _currentSession.copyWith(
      records: updatedRecords,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _currentSession = updatedSession;
    });

    try {
      await widget.sessionRepository.saveSnapshot(
        updatedSession,
        actor: 'User',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  Future<void> _editMemberName(Member member) async {
    final controller = TextEditingController(text: member.displayName);
    final isVisitor = member.isVisitor;

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isVisitor ? 'Rename Visitor' : 'Rename Member (Local)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter new name',
              ),
            ),
            if (!isVisitor)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Note: This only changes the name for "${_currentSession.title}" on ${DateFormat('MMM d, yyyy').format(_currentSession.sessionDate)} to preserve historical accuracy.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
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

    // 1. Remove from records
    final updatedRecords = _currentSession.records.where((r) {
      if (member.isVisitor) {
        return r.memberId != null || r.attendee != member.displayName;
      } else {
        return r.memberId != member.id;
      }
    }).toList();

    // 2. If it's a regular member, add to excluded list so they don't show up as "Absent"
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final recordByMemberId = <String, SessionRecord>{};
    final recordByVisitorName = <String, SessionRecord>{};
    for (final r in _currentSession.records) {
      if (r.memberId != null) {
        recordByMemberId[r.memberId!] = r;
      } else {
        recordByVisitorName[r.attendee] = r;
      }
    }

    final Map<String, Member> displayMembersMap = {};
    final excludedIds = _currentSession.excludedMemberIds.toSet();
    final memberNames = widget.members.map((m) => m.displayName).toSet();

    for (final m in widget.members) {
      if (excludedIds.contains(m.id)) continue;
      
      final record = recordByMemberId[m.id] ?? recordByVisitorName[m.displayName];
      if (record != null) {
        displayMembersMap[m.id] = Member(
          id: m.id,
          displayName: record.attendee,
          isVisitor: false,
        );
      } else {
        displayMembersMap[m.id] = m;
      }
    }

    for (final record in _currentSession.records) {
      if (record.memberId != null) {
        if (!displayMembersMap.containsKey(record.memberId) && !excludedIds.contains(record.memberId)) {
          displayMembersMap[record.memberId!] = Member(
            id: record.memberId!,
            displayName: record.attendee,
            isVisitor: false,
          );
        }
      } else {
        // Legacy record matching: If name exists in regular members, don't show as visitor
        if (!memberNames.contains(record.attendee)) {
          final visitorId = 'visitor_${record.attendee}';
          if (!displayMembersMap.containsKey(visitorId)) {
            displayMembersMap[visitorId] = Member(
              id: visitorId,
              displayName: record.attendee,
              isVisitor: true,
            );
          }
        }
      }
    }

    final allDisplayMembers = displayMembersMap.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    final presentMembers = <Member>[];
    final absentMembers = <Member>[];

    for (final member in allDisplayMembers) {
      AttendanceStatus status;
      if (member.isVisitor) {
        status = recordByVisitorName[member.displayName]?.status ?? AttendanceStatus.absent;
      } else {
        status = recordByMemberId[member.id]?.status ?? recordByVisitorName[member.displayName]?.status ?? AttendanceStatus.absent;
      }

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
              duration: const Duration(milliseconds: 600),
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

                        // Stats Card
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Session Date: ${DateFormat('MMMM d, yyyy').format(_currentSession.sessionDate)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(24),
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
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Text(
                                              'PRESENT',
                                              style: TextStyle(
                                                color: colorScheme
                                                    .onPrimaryContainer,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${presentMembers.length}',
                                              style: TextStyle(
                                                color: colorScheme.primary,
                                                fontSize: 48,
                                                fontWeight: FontWeight.w500,
                                                height: 1.0,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 60,
                                        color: colorScheme.onPrimaryContainer
                                            .withValues(alpha: 0.2),
                                      ),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Text(
                                              'ABSENT',
                                              style: TextStyle(
                                                color: colorScheme
                                                    .onPrimaryContainer,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${absentMembers.length}',
                                              style: TextStyle(
                                                color: colorScheme.error,
                                                fontSize: 40,
                                                fontWeight: FontWeight.w500,
                                                height: 1.0,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Attendance Roster',
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${allDisplayMembers.length} Total',
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Marked Present Header
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SectionHeaderDelegate(
                            title: 'Marked Present',
                            color: colorScheme.primary,
                          ),
                        ),

                        // Present List
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

                        // Marked Absent Header
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SectionHeaderDelegate(
                            title: 'Marked Absent',
                            color: colorScheme.error,
                          ),
                        ),

                        // Absent List
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

                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
            ),
          ),

          // Finalize Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
              ),
              child: Hero(
                tag: 'fab',
                child: ElevatedButton(
                  onPressed: () {
                    // Trigger Auto-Sync if enabled
                    if (widget.driveService?.isDriveSyncEnabled ?? false) {
                      widget.driveService?.syncFiles(
                        actionTitle: 'Auto Sync (Session Finalized)',
                        tags: ['Auto'],
                      ).catchError((e) => debugPrint('Auto-sync failed: $e'));
                    }
                    Navigator.of(context).pop(_currentSession);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 72),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(36),
                    ),
                    elevation: 4,
                  ).copyWith(
                    overlayColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.pressed)) {
                        return colorScheme.onPrimary.withValues(alpha: 0.2);
                      }
                      return null;
                    }),
                  ),
                  child: const Text(
                    'Finalize Report',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return ListView(
      key: const ValueKey('skeleton'),
      padding: const EdgeInsets.all(16),
      children: [
        // Fake AppBar
        Row(
          children: [
            Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.transparent)),
            const Spacer(),
            AppShimmer(width: 120, height: 20, borderRadius: BorderRadius.circular(24)),
            const Spacer(),
            Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.transparent)),
          ],
        ),
        const SizedBox(height: 24),
        // Session Date
        AppShimmer(
          width: 150,
          height: 16,
          borderRadius: BorderRadius.circular(24),
        ),
        const SizedBox(height: 12),
        // Stats Card
        AppShimmer(
          width: double.infinity,
          height: 140,
          borderRadius: BorderRadius.circular(24),
        ),
        const SizedBox(height: 32),
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppShimmer(width: 180, height: 24, borderRadius: BorderRadius.circular(24)),
            AppShimmer(width: 60, height: 14, borderRadius: BorderRadius.circular(24)),
          ],
        ),
        const SizedBox(height: 24),
        // List items
        ...List.generate(
          5,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                AppShimmer(
                  width: 40,
                  height: 40,
                  borderRadius: BorderRadius.circular(20),
                ),
                const SizedBox(width: 16),
                AppShimmer(
                  width: 120,
                  height: 16,
                  borderRadius: BorderRadius.circular(24),
                ),
                const Spacer(),
                AppShimmer(
                  width: 40,
                  height: 24,
                  borderRadius: BorderRadius.circular(24),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final Color color;

  _SectionHeaderDelegate({required this.title, required this.color});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface.withValues(
        alpha: 0.95,
      ), // Surface color with opacity
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.surfaceContainerHighest,
              width: 0.5,
            ),
          ),
        ),
        width: double.infinity,
        padding: const EdgeInsets.only(bottom: 8),
                 child: Text(
                   title,
                   style: TextStyle(
                     color: color,
                     fontSize: 16,
                     fontWeight: FontWeight.w500,
                   ),
                 ),
        
      ),
    );
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant _SectionHeaderDelegate oldDelegate) {
    return oldDelegate.title != title || oldDelegate.color != color;
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

    return Dismissible(
      key: ValueKey('dismiss_${member.id}_$isPresent'),
      direction: DismissDirection.horizontal,
      background: _buildSwipeBackground(
        context,
        'Rename',
        colorScheme.secondary,
        Icons.edit_outlined,
        true,
      ),
      secondaryBackground: _buildSwipeBackground(
        context,
        'Remove from Report',
        colorScheme.error,
        Icons.delete_outline,
        false,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit();
        } else {
          onRemove();
        }
        return false; // We handle state externally
      },
      child: InkWell(
        onLongPress: onEdit,
        onTap: () => onToggle(!isPresent),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: colorScheme.surfaceContainerHighest),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: member.isVisitor
                      ? colorScheme.secondaryContainer
                      : colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: Center(
                  child: Text(
                    member.displayName.isNotEmpty
                        ? member.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: member.isVisitor
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      style: TextStyle(
                        fontSize: 18,
                        color: colorScheme.onSurface,
                        fontWeight:
                            member.isVisitor ? FontWeight.normal : FontWeight.w500,
                      ),
                    ),
                    Text(
                      member.isVisitor ? 'Visitor' : 'Regular Member',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Attendance Toggle
              Switch(
                value: isPresent,
                onChanged: onToggle,
              ),
            ],
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
      color: color,
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
