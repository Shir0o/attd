import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../data/session.dart';
import '../../../../data/session_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/presentation/attendance_deck_page.dart';
import '../../settings/data/drive_service.dart';
import '../../settings/data/local_backup_service.dart';
import '../../settings/application/theme_controller.dart';
import '../../settings/presentation/settings_page.dart';
import '../data/event_repository.dart';
import '../domain/event.dart';
import '../utils/event_date_utils.dart';
import 'add_event_page.dart';
import 'members_page.dart';
import '../../sessions/presentation/event_history_page.dart';
import '../../attendance/presentation/session_summary_page.dart';
import '../../attendance/models/member.dart';

class HubAttendanceView extends StatefulWidget {
  const HubAttendanceView({
    super.key,
    required this.sessionRepository,
    required this.eventRepository,
    required this.attendanceRepository,
    required this.themeController,
    this.driveService,
    this.localBackupService,
    this.disableAnimations = false,
  });

  final SessionRepository sessionRepository;
  final EventRepository eventRepository;
  final AttendanceRepository attendanceRepository;
  final ThemeController themeController;
  final DriveService? driveService;
  final LocalBackupService? localBackupService;
  final bool disableAnimations;

  @override
  State<HubAttendanceView> createState() => _HubAttendanceViewState();
}

class _HubAttendanceViewState extends State<HubAttendanceView> {
  // Using Stream for real-time updates
  late Stream<List<Event>> _eventsStream;
  List<Member> _members = [];
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _eventsStream = widget.eventRepository.streamEvents().map(_processEvents);
    _loadInitialData();

    // Listen to DriveService for sync status updates
    widget.driveService?.addListener(_onDriveServiceChange);
  }

  Future<void> _loadInitialData() async {
    setState(() => _isInitialLoading = true);
    final startTime = DateTime.now();

    await Future.wait([
      _loadMembers(),
      // Add any other necessary initial loads here
    ]);

    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(milliseconds: 800) - elapsed;
    if (remaining > Duration.zero && !widget.disableAnimations) {
      await Future.delayed(remaining);
    }

    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }

  @override
  void dispose() {
    widget.driveService?.removeListener(_onDriveServiceChange);
    super.dispose();
  }

  void _onDriveServiceChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMembers() async {
    try {
      final families = await widget.attendanceRepository.fetchFamilies();
      if (mounted) {
        setState(() {
          _members = families.expand((f) => f.members).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading members: $e');
    }
  }

  void _createNewSession() async {
    debugPrint('DEBUG: _createNewSession called');
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEventPage(
          eventRepository: widget.eventRepository,
          disableAnimations: widget.disableAnimations,
        ),
      ),
    );
    if (mounted) _loadMembers();
  }

  void _editEvent(Event event) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEventPage(
          eventRepository: widget.eventRepository,
          eventToEdit: event,
          disableAnimations: widget.disableAnimations,
        ),
      ),
    );
    if (mounted) _loadMembers();
  }

  Future<void> _deleteEvent(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
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
        await widget.eventRepository.deleteEvent(event.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting event: $e')));
        }
      }
    }
  }

  void _showEventMenu(BuildContext context, Event event) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return RepaintBoundary(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Handle bar
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('View History'),
                onTap: () {
                  Navigator.pop(context, 'history');
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Event'),
                onTap: () {
                  Navigator.pop(context, 'edit');
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Manage Members'),
                onTap: () {
                  Navigator.pop(context, 'manage');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Event',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context, 'delete');
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (action == 'history') {
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventHistoryPage(
            event: event,
            sessionRepository: widget.sessionRepository,
            attendanceRepository: widget.attendanceRepository,
          ),
        ),
      );
    } else if (action == 'edit') {
      _editEvent(event);
    } else if (action == 'manage') {
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MembersPage(
            attendanceRepository: widget.attendanceRepository,
            event: event,
            eventRepository: widget.eventRepository,
          ),
        ),
      );
      if (mounted) _loadMembers();
    } else if (action == 'delete') {
      _deleteEvent(event);
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isEventToday(Event event) {
    final now = DateTime.now();
    if (event.frequency == 'One-time') {
      return event.oneTimeDate != null && _isToday(event.oneTimeDate!);
    } else {
      // Repeating event
      final todayWeekday = DateFormat('EEEE').format(now);
      final isToday = event.repeatingDays.contains(todayWeekday);
      return isToday;
    }
  }

  List<Event> _processEvents(List<Event> events) {
    final todayEvents = <Event>[];
    final otherEvents = <Event>[];

    for (final event in events) {
      if (_isEventToday(event)) {
        todayEvents.add(event);
      } else {
        otherEvents.add(event);
      }
    }

    // Sort within groups if needed (e.g. by time)
    todayEvents.sort((a, b) {
      final timeA = a.time.hour * 60 + a.time.minute;
      final timeB = b.time.hour * 60 + b.time.minute;
      return timeA.compareTo(timeB);
    });

    return [...todayEvents, ...otherEvents];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSyncing = widget.driveService?.isSyncing ?? false;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.eventRepository.refresh();
          await widget.sessionRepository.refresh();
          await widget.attendanceRepository.refresh();
          await _loadMembers();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: colorScheme.surface,
              floating: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TODAY',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    DateFormat(
                      'EEE, MMM d',
                    ).format(DateTime.now()).toUpperCase(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              actions: [
                if (widget.driveService != null &&
                    widget.localBackupService != null)
                  IconButton(
                    icon: Icon(
                      Icons.settings,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () async {
                      final dataModified = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => SettingsPage(
                            themeController: widget.themeController,
                            driveService: widget.driveService!,
                            localBackupService: widget.localBackupService!,
                            attendanceRepository: widget.attendanceRepository,
                            eventRepository: widget.eventRepository,
                            sessionRepository: widget.sessionRepository,
                            disableAnimations: widget.disableAnimations,
                          ),
                        ),
                      );

                      // Only refresh if data was actually modified
                      if (mounted && dataModified == true) {
                        await Future.wait([
                          widget.eventRepository.refresh(),
                          widget.sessionRepository.refresh(),
                          widget.attendanceRepository.refresh(),
                          _loadInitialData(),
                        ]);
                      }
                    },
                  ),
              ],
              expandedHeight: 100,
              toolbarHeight: 80,
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: StreamBuilder<List<Session>>(
                stream: widget.sessionRepository.streamSessions(),
                builder: (context, sessionSnapshot) {
                  final sessions = sessionSnapshot.data ?? [];
                  return StreamBuilder<List<Event>>(
                    stream: _eventsStream,
                    builder: (context, snapshot) {
                      final isLoading =
                          _isInitialLoading ||
                          snapshot.connectionState == ConnectionState.waiting ||
                          (isSyncing &&
                              (snapshot.data == null ||
                                  snapshot.data!.isEmpty));

                      if (isLoading) {
                        return SliverList(
                          key: const ValueKey('hub_skeleton'),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _EventCardSkeleton(
                                disableAnimations: widget.disableAnimations,
                              ),
                            ),
                            childCount: 3,
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              'No events created yet',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      }

                      final sortedEvents = snapshot.data!;

                      return SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final event = sortedEvents[index];
                          final isToday = _isEventToday(event);

                          // Logic for display stats:
                          // We want to show stats for the "current relevant session" for this event.
                          // Usually 'today', but if we are late, maybe previous week?
                          // For simplicity on the Hub card, let's stick to 'Today's session' if it exists.

                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final lastSupposed = getLastSupposedOccurrence(
                            event,
                            now,
                          );

                          // Find the most recent session for this event
                          final eventSessions = sessions.where((s) {
                            if (s.eventId != null && s.eventId!.isNotEmpty) {
                              return s.eventId == event.id;
                            }
                            // Legacy fallback: only match by title if no eventId is present
                            return s.title.trim() == event.title.trim();
                          }).toList();
                          eventSessions.sort(
                            (a, b) => b.sessionDate.compareTo(a.sessionDate),
                          );

                          // A session is considered "current" if it's on or after the last supposed occurrence
                          Session? targetSession;
                          if (eventSessions.isNotEmpty) {
                            final latest = eventSessions.first;
                            final latestDate = DateTime(
                              latest.sessionDate.year,
                              latest.sessionDate.month,
                              latest.sessionDate.day,
                            );
                            if (!latestDate.isBefore(lastSupposed)) {
                              targetSession = latest;
                            }
                          }

                          final hasSession = targetSession != null;
                          final displayDate =
                              targetSession?.sessionDate ?? lastSupposed;

                          String attendanceStatus;
                          bool isActionable = false;
                          if (lastSupposed.isAfter(today)) {
                            attendanceStatus = 'Upcoming';
                          } else {
                            final isTargetToday =
                                displayDate.year == today.year &&
                                displayDate.month == today.month &&
                                displayDate.day == today.day;
                            if (isTargetToday) {
                              if (hasSession) {
                                attendanceStatus = 'Taken today';
                              } else {
                                attendanceStatus = 'Start';
                                isActionable = true;
                              }
                            } else {
                              final dateStr = DateFormat(
                                'MMM d',
                              ).format(displayDate);
                              if (hasSession) {
                                attendanceStatus = 'Taken ($dateStr)';
                              } else {
                                attendanceStatus = 'Start';
                                isActionable = true;
                              }
                            }
                          }

                          return RepaintBoundary(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _EventCard(
                                event: event,
                                isToday: isToday,
                                attendanceStatus: attendanceStatus,
                                isActionable: isActionable,
                                onTap: () async {
                                  // 1. Calculate target date
                                  final targetDate = calculateTargetDate(
                                    event,
                                    DateTime.now(),
                                  );

                                  // 2. Find existing session for target date (or most recent relevant)
                                  final eventSessionsOnTap = sessions.where((
                                    s,
                                  ) {
                                    if (s.eventId != null &&
                                        s.eventId!.isNotEmpty) {
                                      return s.eventId == event.id;
                                    }
                                    // Legacy fallback: only match by title if no eventId is present
                                    return s.title.trim() == event.title.trim();
                                  }).toList();
                                  eventSessionsOnTap.sort(
                                    (a, b) =>
                                        b.sessionDate.compareTo(a.sessionDate),
                                  );

                                  Session? foundSession;
                                  if (eventSessionsOnTap.isNotEmpty) {
                                    final latest = eventSessionsOnTap.first;
                                    final latestDate = DateTime(
                                      latest.sessionDate.year,
                                      latest.sessionDate.month,
                                      latest.sessionDate.day,
                                    );
                                    if (!latestDate.isBefore(targetDate)) {
                                      foundSession = latest;
                                    }
                                  }

                                  // 3. Filter members
                                  final sessionMembers =
                                      event.memberIds.isNotEmpty
                                      ? _members
                                            .where(
                                              (m) => event.memberIds.contains(
                                                m.id,
                                              ),
                                            )
                                            .toList()
                                      : _members;

                                  if (foundSession != null) {
                                    // Session exists
                                    final sessionToOpen = foundSession;

                                    // If the session is "empty" or "incomplete", go to Deck to resume/start
                                    // If it's fully marked, go to Summary
                                    final bool isIncomplete =
                                        sessionToOpen.records.length <
                                        sessionMembers.length;

                                    if (isIncomplete) {
                                      var resultSession =
                                          await Navigator.of(
                                            context,
                                          ).push<Session>(
                                            MaterialPageRoute(
                                              builder: (_) => AttendanceDeckPage(
                                                session: sessionToOpen,
                                                members: sessionMembers,
                                                sessionRepository:
                                                    widget.sessionRepository,
                                                attendanceRepository:
                                                    widget.attendanceRepository,
                                              ),
                                            ),
                                          );

                                      // Performance Optimization: Fallback only if Navigator.pop didn't return session (e.g. swipe back)
                                      resultSession ??= await widget
                                          .sessionRepository
                                          .findSessionById(sessionToOpen.id);

                                      // Cleanup if still empty after returning
                                      if (resultSession != null &&
                                          resultSession.records.isEmpty) {
                                        await widget.sessionRepository
                                            .deleteSession(
                                              sessionToOpen.id,
                                              actor: 'System (Cleanup)',
                                            );
                                      }
                                    } else {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SessionSummaryPage(
                                            session: sessionToOpen,
                                            members: sessionMembers,
                                            sessionRepository:
                                                widget.sessionRepository,
                                          ),
                                        ),
                                      );
                                    }
                                  } else {
                                    // Session does not exist -> Create new -> Deck
                                    final session = await widget
                                        .sessionRepository
                                        .createSession(
                                          title: event.title,
                                          eventId: event.id,
                                          sessionDate: targetDate,
                                          actor: 'User',
                                          records: [],
                                        );

                                    if (!context.mounted) return;

                                    var resultSession =
                                        await Navigator.of(
                                          context,
                                        ).push<Session>(
                                          MaterialPageRoute(
                                            builder: (_) => AttendanceDeckPage(
                                              session: session,
                                              members: sessionMembers,
                                              sessionRepository:
                                                  widget.sessionRepository,
                                              attendanceRepository:
                                                  widget.attendanceRepository,
                                            ),
                                          ),
                                        );

                                    // Performance Optimization: Fallback only if Navigator.pop didn't return session (e.g. swipe back)
                                    resultSession ??= await widget
                                        .sessionRepository
                                        .findSessionById(session.id);

                                    // Check if the session was actually used/finished
                                    if (resultSession != null &&
                                        resultSession.records.isEmpty) {
                                      // If no records were added, assume the user cancelled/aborted
                                      await widget.sessionRepository
                                          .deleteSession(
                                            session.id,
                                            actor: 'System (Cleanup)',
                                          );
                                    }
                                  }

                                  if (mounted) _loadMembers();
                                },
                                onMenuTap: () => _showEventMenu(context, event),
                                primaryColor: colorScheme.primary,
                                onPrimaryColor: colorScheme.onPrimary,
                                surfaceContainerColor:
                                    colorScheme.surfaceContainer,
                                onSurfaceColor: colorScheme.onSurface,
                                onSurfaceVariantColor:
                                    colorScheme.onSurfaceVariant,
                                secondaryContainerColor:
                                    colorScheme.secondaryContainer,
                                onSecondaryContainerColor:
                                    colorScheme.onSecondaryContainer,
                                disableAnimations: widget.disableAnimations,
                              ),
                            ),
                          );
                        }, childCount: sortedEvents.length),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('hub_fab'),
        heroTag: 'fab',
        onPressed: _createNewSession,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: const Icon(Icons.add, size: 24),
      ),
    );
  }
}

class _EventCard extends StatefulWidget {
  const _EventCard({
    required this.event,
    required this.isToday,
    required this.onTap,
    required this.onMenuTap,
    required this.primaryColor,
    required this.onPrimaryColor,
    required this.surfaceContainerColor,
    required this.onSurfaceColor,
    required this.onSurfaceVariantColor,
    required this.secondaryContainerColor,
    required this.onSecondaryContainerColor,
    required this.attendanceStatus,
    this.isActionable = false,
    this.disableAnimations = false,
  });

  final Event event;
  final bool isToday;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;
  final Color primaryColor;
  final Color onPrimaryColor;
  final Color surfaceContainerColor;
  final Color onSurfaceColor;
  final Color onSurfaceVariantColor;
  final Color secondaryContainerColor;
  final Color onSecondaryContainerColor;
  final String attendanceStatus;
  final bool isActionable;
  final bool disableAnimations;

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        // The HTML uses a 70% keyframe for max spread, we can simulate with Sine or custom timing.
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    if (widget.isToday && !widget.disableAnimations) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _EventCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isToday && !oldWidget.isToday && !widget.disableAnimations) {
      _pulseController.repeat();
    } else if (!widget.isToday && oldWidget.isToday) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildRepeatingDaysRow() {
    final dayOrder = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: dayOrder.map((day) {
          final isActive = widget.event.repeatingDays.contains(day);
          final bg = isActive
              ? widget.primaryColor
              : Theme.of(context).colorScheme.surfaceContainerHigh;
          final fg = isActive
              ? widget.onPrimaryColor
              : widget.onSurfaceVariantColor;

          return Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              day.substring(0, 1),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: fg,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAttendanceStatusPill(String status) {
    if (status.startsWith('Start')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: widget.primaryColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: widget.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: widget.onPrimaryColor,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.play_arrow, size: 18, color: widget.onPrimaryColor),
          ],
        ),
      );
    } else if (status.startsWith('Taken')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: widget.secondaryContainerColor,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 18,
              color: widget.onSecondaryContainerColor,
            ),
            const SizedBox(width: 8),
            Text(
              'COMPLETED',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: widget.onSecondaryContainerColor,
              ),
            ),
          ],
        ),
      );
    } else {
      // Upcoming, Missed, etc. Keep plain text style as a fallback.
      return Text(
        status,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: widget.onSurfaceVariantColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: widget.surfaceContainerColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 200),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.isToday)
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              // Fade out the shadow as it expands based on animation value
                              final opacity =
                                  1.0 -
                                  (_pulseController.value / 0.7).clamp(
                                    0.0,
                                    1.0,
                                  );
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.primaryColor,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.primaryColor.withOpacity(
                                        opacity * 0.4,
                                      ),
                                      blurRadius: 0,
                                      spreadRadius: _pulseAnimation.value,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'TODAY',
                                  style: TextStyle(
                                    color: widget.onPrimaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              );
                            },
                          ),
                        Text(
                          widget.event.title,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w500,
                            color: widget.onSurfaceColor,
                            height: 1.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        if (widget.event.frequency == 'One-time')
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: widget.onSurfaceVariantColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.event.oneTimeDate != null
                                    ? DateFormat(
                                        'EEEE, MMM d, yyyy',
                                      ).format(widget.event.oneTimeDate!)
                                    : 'One-time Event',
                                style: TextStyle(
                                  color: widget.onSurfaceVariantColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        else if (widget.event.repeatingDays.isNotEmpty)
                          _buildRepeatingDaysRow(),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: widget.onSurfaceVariantColor,
                    ),
                    onPressed: widget.onMenuTap,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 20,
                        color: widget.onSurfaceVariantColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.event.time.format(context),
                        style: TextStyle(
                          fontSize: 18,
                          color: widget.onSurfaceVariantColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  _buildAttendanceStatusPill(widget.attendanceStatus),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCardSkeleton extends StatelessWidget {
  const _EventCardSkeleton({this.disableAnimations = false});

  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseColor = colorScheme.surfaceContainer;

    return Card(
      elevation: 0,
      color: baseColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 200),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _ShimmerBox(
                            width: 60,
                            height: 24,
                            borderRadius: BorderRadius.circular(28),
                            disableAnimations: disableAnimations,
                          ),
                          const SizedBox(width: 8),
                          _ShimmerBox(
                            width: 80,
                            height: 24,
                            borderRadius: BorderRadius.circular(28),
                            disableAnimations: disableAnimations,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ShimmerBox(
                        width: 200,
                        height: 32,
                        disableAnimations: disableAnimations,
                      ),
                      const SizedBox(height: 8),
                      _ShimmerBox(
                        width: 140,
                        height: 32,
                        disableAnimations: disableAnimations,
                      ),
                    ],
                  ),
                ),
                _ShimmerBox(
                  width: 24,
                  height: 24,
                  disableAnimations: disableAnimations,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _ShimmerBox(
                      width: 20,
                      height: 20,
                      disableAnimations: disableAnimations,
                    ),
                    const SizedBox(width: 8),
                    _ShimmerBox(
                      width: 80,
                      height: 20,
                      disableAnimations: disableAnimations,
                    ),
                  ],
                ),
                _ShimmerBox(
                  width: 120,
                  height: 36,
                  borderRadius: BorderRadius.circular(28),
                  disableAnimations: disableAnimations,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius,
    this.disableAnimations = false,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final bool disableAnimations;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    if (!widget.disableAnimations) {
      _controller.repeat();
    }

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseColor = colorScheme.surfaceContainerHigh;
    final highlightColor = colorScheme.surfaceContainerLowest;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                0.0,
                (_animation.value + 1) / 2, // Map -2..2 to roughly 0..1
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
}
