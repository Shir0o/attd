import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/session.dart';
import '../../../../data/session_record.dart';
import '../../../../data/session_repository.dart';
import '../models/attendance_status.dart';
import '../models/member.dart';

class SessionSummaryPage extends StatefulWidget {
  const SessionSummaryPage({
    super.key,
    required this.session,
    required this.members,
    required this.sessionRepository,
  });

  final Session session;
  final List<Member> members;
  final SessionRepository sessionRepository;

  @override
  State<SessionSummaryPage> createState() => _SessionSummaryPageState();
}

class _SessionSummaryPageState extends State<SessionSummaryPage> {
  late Session _currentSession;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session;
    _refreshLatest();
  }

  Future<void> _refreshLatest() async {
    final startTime = DateTime.now();
    
    final latest = await widget.sessionRepository.findSessionById(
      _currentSession.id,
    );

    if (latest != null && mounted) {
      setState(() {
        _currentSession = latest;
      });
    }

    // Ensure minimum loading duration for visual consistency
    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(milliseconds: 400) - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAttendance(Member member, bool isPresent) async {
    final status = isPresent
        ? AttendanceStatus.present
        : AttendanceStatus.absent;
    final attendeeName = member.displayName;

    final newRecord = SessionRecord(
      attendee: attendeeName,
      status: status,
      recordedAt: DateTime.now(),
      recordedBy: 'User', // Placeholder
    );

    // Update session locally
    final updatedRecords = List<SessionRecord>.from(_currentSession.records);
    final existingIndex = updatedRecords.indexWhere(
      (r) => r.attendee == attendeeName,
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

    // Save to repo
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

  AttendanceStatus _getStatus(Member member) {
    // Check if member has a record in the session
    for (final record in _currentSession.records) {
      if (record.attendee == member.displayName) {
        return record.status;
      }
    }
    // If no record, default to absent? Or defaultStatus?
    // Since deck flow forces a choice, we assume Absent if not found for summary.
    return AttendanceStatus.absent;
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
      try {
        await widget.sessionRepository.deleteSession(
          _currentSession.id,
          actor: 'You',
        );
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Session deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting session: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final presentMembers = <Member>[];
    final absentMembers = <Member>[];

    for (final member in widget.members) {
      if (_getStatus(member) == AttendanceStatus.present) {
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
                            onPressed: () => Navigator.of(context).pop(),
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
                                    borderRadius: BorderRadius.circular(16),
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
                                      '${widget.members.length} Total',
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
                  onPressed: () => Navigator.of(context).pop(),
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
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      key: const ValueKey('skeleton'),
      padding: const EdgeInsets.all(16),
      children: [
        // Fake AppBar
        Row(
          children: [
            Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.transparent)),
            const Spacer(),
            Container(width: 120, height: 20, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4))),
            const Spacer(),
            Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.transparent)),
          ],
        ),
        const SizedBox(height: 24),
        // Session Date
        Container(
          width: 150,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        // Stats Card
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 32),
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(width: 180, height: 24, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4))),
            Container(width: 60, height: 14, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4))),
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 40,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
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

  const _MemberListItem({
    required this.member,
    required this.isPresent,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
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
                    ),
                  ),
                  if (member.isVisitor)
                    Text(
                      'Added today',
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            // Toggle Switch
            Switch(
              value: isPresent,
              onChanged: onToggle,
              activeThumbColor: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
