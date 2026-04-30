import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_theme.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';

import '../../../../data/session.dart';
import '../../../../data/session_record.dart';
import '../../../../data/session_repository.dart';
import '../../hub/domain/event.dart';
import '../../hub/data/event_repository.dart';
import '../../attendance/presentation/session_summary_page.dart';
import '../../attendance/presentation/attendance_deck_page.dart';
import '../../attendance/models/attendance_status.dart';
import '../../attendance/utils/session_roster_utils.dart';
import '../../settings/data/drive_service.dart';

class EventHistoryPage extends StatefulWidget {
  const EventHistoryPage({
    super.key,
    required this.event,
    required this.sessionRepository,
    required this.attendanceRepository,
    required this.eventRepository,
    this.driveService,
    this.disableAnimations = false,
  });

  final Event event;
  final SessionRepository sessionRepository;
  final AttendanceRepository attendanceRepository;
  final EventRepository eventRepository;
  final DriveService? driveService;
  final bool disableAnimations;

  @override
  State<EventHistoryPage> createState() => _EventHistoryPageState();
}

class _EventHistoryPageState extends State<EventHistoryPage> {
  late Stream<List<Session>> _sessionsStream;
  late Future<void> _initializationFuture;
  List<Member> _members = [];

  @override
  void initState() {
    super.initState();
    _sessionsStream = widget.sessionRepository.streamSessions();
    _initializationFuture = _init();
  }

  Future<void> _init() async {
    final startTime = DateTime.now();
    
    try {
      // Parallelize member loading and initial session load
      await Future.wait([
        widget.attendanceRepository.fetchFamilies().then((families) {
          if (mounted) {
            _members = families.expand((f) => f.members).toList();
          }
        }),
        widget.sessionRepository.loadSessions(),
      ]);
    } catch (e) {
      debugPrint('Error during initialization: $e');
    }

    // Minimum loading duration for visual consistency
    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(milliseconds: 800) - elapsed;

    if (remaining > Duration.zero && !widget.disableAnimations) {
      await Future.delayed(remaining);
    }
  }

  Future<void> _deleteSession(Session session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text(
          'Are you sure you want to delete "${session.title}" for ${DateFormat('yyyy-MM-dd').format(session.sessionDate)}?',
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
          session.id,
          actor: 'You',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting session: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          '${widget.event.title.trim()} History',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: RepaintBoundary(
        child: FutureBuilder<void>(
          future: _initializationFuture,
          builder: (context, initSnapshot) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: initSnapshot.connectionState != ConnectionState.done
                  ? _buildSkeleton(context)
                  : RefreshIndicator(
                      key: const ValueKey('content'),
                      onRefresh: () async {
                        await widget.sessionRepository.refresh();
                        await widget.attendanceRepository.refresh();
                        await _init();
                      },
                      child: StreamBuilder<List<Session>>(
                        stream: _sessionsStream,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return _buildSkeleton(context);
                          }

                          final allSessions = snapshot.data ?? [];
                          final eventSessions = allSessions.where((s) {
                            if (s.eventId != null && s.eventId!.isNotEmpty) {
                              return s.eventId == widget.event.id;
                            }
                            // Legacy fallback: only match by title if no eventId is present
                            return s.title.trim() == widget.event.title.trim();
                          }).toList();

                          // Sort by date descending
                          eventSessions.sort(
                            (a, b) => b.sessionDate.compareTo(a.sessionDate),
                          );

                          if (eventSessions.isEmpty) {
                            return LayoutBuilder(
                              builder: (context, constraints) => ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  Container(
                                    constraints: BoxConstraints(
                                      minHeight: constraints.maxHeight,
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.history_outlined,
                                            size: 64,
                                            color: colorScheme.onSurfaceVariant
                                                .withOpacity(0.5),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No history found',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: eventSessions.length,
                            separatorBuilder:
                                (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final session = eventSessions[index];
                              final dateStr = DateFormat('MMM d, yyyy').format(
                                session.sessionDate,
                              );
                              final dayTimeStr =
                                  '${DateFormat('EEEE').format(session.sessionDate)} • ${widget.event.time.format(context)}';

                              // Filter members to only those assigned to this event
                              final filteredMembers = widget.event.memberIds.isNotEmpty
                                  ? _members
                                      .where((m) => widget.event.memberIds.contains(m.id))
                                      .toList()
                                  : _members;

                              // Consistency fix: use the shared SessionRoster logic
                              final roster = SessionRoster(session, filteredMembers);

                              int totalPresent = 0;
                              int totalAbsent = 0;

                              for (final member in roster.displayMembersMap.values) {
                                final status = roster.getStatus(member);

                                if (status == AttendanceStatus.present) {
                                  totalPresent++;
                                } else {
                                  totalAbsent++;
                                }
                              }

                              return Dismissible(
                                key: ValueKey('dismiss_session_${session.id}'),
                                direction: DismissDirection.endToStart,
                                background: Container(color: Colors.transparent), // Required by Flutter if secondaryBackground is set
                                secondaryBackground: _buildSwipeBackground(
                                  context,
                                  'Delete Session',
                                  colorScheme.error,
                                  Icons.delete_outline,
                                  false,
                                ),
                                confirmDismiss: (direction) async {
                                  if (direction == DismissDirection.endToStart) {
                                    await _deleteSession(session);
                                  }
                                  return false;
                                },
                                child: Card(
                                  elevation: 0,
                                  color: colorScheme.secondaryContainer
                                      .withOpacity(0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                    side: BorderSide(
                                      color: colorScheme.surfaceContainerHighest
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SessionSummaryPage(
                                                session: session,
                                                members: filteredMembers,
                                                sessionRepository:
                                                    widget.sessionRepository,
                                                attendanceRepository:
                                                    widget.attendanceRepository,
                                                eventRepository:
                                                    widget.eventRepository,
                                                event: widget.event,
                                                driveService: widget.driveService,
                                                disableAnimations: widget.disableAnimations,
                                              ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      dateStr,
                                                      style: TextStyle(
                                                        fontSize: 22,
                                                        fontWeight: FontWeight.w500,
                                                        color: colorScheme.onSurface,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      dayTimeStr,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.chevron_right,
                                                color:
                                                    colorScheme.onSurfaceVariant,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildStatusBadge(
                                                  context,
                                                  Icons.check_circle,
                                                  colorScheme.primary,
                                                  '$totalPresent Present',
                                                ),
                                              ),
                                              Container(
                                                height: 16,
                                                width: 1,
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                    ),
                                                color: colorScheme.outlineVariant,
                                              ),
                                              Expanded(
                                                child: _buildStatusBadge(
                                                  context,
                                                  Icons.cancel,
                                                  colorScheme.error,
                                                  '$totalAbsent Absent',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab',
        onPressed: () => _showMakeUpDatePicker(context),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        child: const Icon(Icons.add, size: 24),
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
      margin: const EdgeInsets.symmetric(vertical: 0),
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

  Future<void> _showMakeUpDatePicker(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (pickedDate != null && mounted) {
      // Find event time
      final targetDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        widget.event.time.hour,
        widget.event.time.minute,
      );

      // 1. Create session (similar to HubAttendanceView logic)
      final session = await widget.sessionRepository.createSession(
        title: widget.event.title,
        eventId: widget.event.id,
        sessionDate: targetDate,
        actor: 'User (Manual Make-up)',
        records: [],
      );

      if (!mounted) return;

      // 2. Filter members for this event
      final sessionMembers = widget.event.memberIds.isNotEmpty
          ? _members.where((m) => widget.event.memberIds.contains(m.id)).toList()
          : _members;

      // 3. Navigate to AttendanceDeckPage
      final resultSession = await Navigator.of(context).push<Session>(
        MaterialPageRoute(
          builder:
              (_) => AttendanceDeckPage(
                session: session,
                members: sessionMembers,
                sessionRepository: widget.sessionRepository,
                attendanceRepository: widget.attendanceRepository,
                eventRepository: widget.eventRepository,
                event: widget.event,
                disableAnimations: widget.disableAnimations,
              ),
        ),
      );

      // Cleanup if empty after returning (consistency with Hub logic)
      final finalSession =
          resultSession ??
          await widget.sessionRepository.findSessionById(session.id);

      if (finalSession != null && finalSession.records.isEmpty) {
        await widget.sessionRepository.deleteSession(
          session.id,
          actor: 'System (Cleanup)',
        );
      }
    }
  }

  Widget _buildSkeleton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          height: 140,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppShimmer(
                width: 140,
                height: 24,
                borderRadius: BorderRadius.circular(24),
                disableAnimations: widget.disableAnimations,
              ),
              const SizedBox(height: 10),
              AppShimmer(
                width: 200,
                height: 16,
                borderRadius: BorderRadius.circular(24),
                disableAnimations: widget.disableAnimations,
              ),
              const Spacer(),
              Row(
                children: [
                  AppShimmer(
                    width: 100,
                    height: 20,
                    borderRadius: BorderRadius.circular(24),
                    disableAnimations: widget.disableAnimations,
                  ),
                  const SizedBox(width: 32),
                  AppShimmer(
                    width: 100,
                    height: 20,
                    borderRadius: BorderRadius.circular(24),
                    disableAnimations: widget.disableAnimations,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(
    BuildContext context,
    IconData icon,
    Color color,
    String label,
  ) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
