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
import '../../attendance/models/attendance_status.dart';
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
  });

  final SessionRepository sessionRepository;
  final EventRepository eventRepository;
  final AttendanceRepository attendanceRepository;
  final ThemeController themeController;
  final DriveService? driveService;
  final LocalBackupService? localBackupService;

  @override
  State<HubAttendanceView> createState() => _HubAttendanceViewState();
}

class _HubAttendanceViewState extends State<HubAttendanceView> {
  // Using Stream for real-time updates
  late Stream<List<Event>> _eventsStream;
  List<Member> _members = [];

  @override
  void initState() {
    super.initState();
    _eventsStream = widget.eventRepository.streamEvents().map(_processEvents);
    _loadMembers();
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEventPage(eventRepository: widget.eventRepository),
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
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SettingsPage(
                            themeController: widget.themeController,
                            driveService: widget.driveService!,
                            localBackupService: widget.localBackupService!,
                            attendanceRepository: widget.attendanceRepository,
                          ),
                        ),
                      );
                      // Refresh after returning from Settings
                      if (mounted) {
                        await widget.eventRepository.refresh();
                        await widget.sessionRepository.refresh();
                        await widget.attendanceRepository.refresh();
                        await _loadMembers();
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
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return SliverFillRemaining(
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

                          // Try to find a session for today for this event
                          final matchingSessions = sessions.where(
                            (s) =>
                                (s.eventId == event.id || s.title == event.title) &&
                                s.sessionDate.year == today.year &&
                                s.sessionDate.month == today.month &&
                                s.sessionDate.day == today.day,
                          );
                          Session? todaySession = matchingSessions.isNotEmpty
                              ? matchingSessions.first
                              : null;

                          final scannedCount =
                              todaySession?.records
                                  .where(
                                    (r) => r.status == AttendanceStatus.present,
                                  )
                                  .length ??
                              0;

                          // Total count: use event specific members if available, else all members
                          final totalCount = event.memberIds.isNotEmpty
                              ? event.memberIds.length
                              : _members.length;

                          return RepaintBoundary(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _EventCard(
                                event: event,
                                isToday: isToday,
                                scannedCount: scannedCount,
                                totalCount: totalCount,
                                onTap: () async {
                                  // 1. Calculate target date
                                  final targetDate = calculateTargetDate(event, DateTime.now());

                                  // 2. Find existing session for target date
                                  final existingSessions = sessions.where((s) =>
                                    (s.eventId == event.id || s.title == event.title) &&
                                    s.sessionDate.year == targetDate.year &&
                                    s.sessionDate.month == targetDate.month &&
                                    s.sessionDate.day == targetDate.day
                                  );

                                  Session? targetSession = existingSessions.isNotEmpty
                                      ? existingSessions.first
                                      : null;

                                  // 3. Filter members
                                  final sessionMembers = event.memberIds.isNotEmpty
                                      ? _members.where((m) => event.memberIds.contains(m.id)).toList()
                                      : _members;

                                  if (targetSession != null) {
                                    // Session exists -> Summary
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => SessionSummaryPage(
                                          session: targetSession!,
                                          members: sessionMembers,
                                          sessionRepository:
                                              widget.sessionRepository,
                                        ),
                                      ),
                                    );
                                  } else {
                                    // Session does not exist -> Create new -> Deck
                                    final session = await widget.sessionRepository
                                        .createSession(
                                          title: event.title,
                                          eventId: event.id,
                                          sessionDate: targetDate,
                                          actor: 'User',
                                          records: [],
                                        );

                                    if (!context.mounted) return;

                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => AttendanceDeckPage(
                                          session: session,
                                          members: sessionMembers,
                                          sessionRepository:
                                              widget.sessionRepository,
                                        ),
                                      ),
                                    );
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
        heroTag: 'fab',
        onPressed: _createNewSession,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 24),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
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
    required this.scannedCount,
    required this.totalCount,
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
  final int scannedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: surfaceContainerColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                        if (isToday)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'TODAY',
                                  style: TextStyle(
                                    color: onPrimaryColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const SizedBox(height: 34), // Spacer

                        Text(
                          event.title,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w500,
                            color: onSurfaceColor,
                            height: 1.1,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: onSurfaceVariantColor),
                    onPressed: onMenuTap,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 20,
                          color: onSurfaceVariantColor,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            event.time.format(context),
                            style: TextStyle(
                              fontSize: 20,
                              color: onSurfaceVariantColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Placeholder for scan count if needed
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isToday
                          ? secondaryContainerColor
                          : surfaceContainerColor.withAlpha(
                              20,
                            ), // Less prominent
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: onSurfaceVariantColor.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '/ Present',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: onSurfaceVariantColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
