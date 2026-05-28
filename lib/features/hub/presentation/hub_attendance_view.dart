import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../../../data/session.dart';
import '../../../data/session_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';
import '../../attendance/presentation/attendance_deck_page.dart';
import '../../attendance/presentation/session_summary_page.dart';
import '../../attendance/models/attendance_start_mode.dart';
import '../../attendance/presentation/start_mode_picker.dart';
import '../../attendance/utils/session_preseed.dart';
import '../../settings/application/app_lock_controller.dart';
import '../../settings/application/theme_controller.dart';
import '../data/event_repository.dart';
import '../domain/event.dart';
import '../utils/event_date_utils.dart';
import '../../settings/data/drive_service.dart';
import '../../settings/data/local_backup_service.dart';
import 'members_page.dart';
import 'add_event_page.dart';
import '../../sessions/presentation/event_history_page.dart';
import '../../settings/presentation/settings_page.dart';

class HubAttendanceView extends StatefulWidget {
  const HubAttendanceView({
    super.key,
    required this.themeController,
    required this.sessionRepository,
    required this.eventRepository,
    required this.attendanceRepository,
    this.driveService,
    this.localBackupService,
    this.appLockController,
    this.disableAnimations = false,
  });

  final ThemeController themeController;
  final SessionRepository sessionRepository;
  final EventRepository eventRepository;
  final AttendanceRepository attendanceRepository;
  final DriveService? driveService;
  final LocalBackupService? localBackupService;
  final AppLockController? appLockController;
  final bool disableAnimations;

  @override
  State<HubAttendanceView> createState() => _HubAttendanceViewState();
}

class _HubAttendanceViewState extends State<HubAttendanceView> {
  List<Member> _members = [];
  List<Family> _families = [];
  bool _isLoading = true;
  List<Event> _events = [];
  List<Session> _sessions = [];
  StreamSubscription? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _subscribeToData();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToData() {
    final startTime = DateTime.now();
    _isLoading = true;

    _dataSubscription?.cancel();
    _dataSubscription = widget.eventRepository.streamEvents().listen((events) async {
      final sessions = await widget.sessionRepository.loadSessions();
      
      if (mounted) {
        setState(() {
          _events = events;
          _sessions = sessions;
        });

        // Mandatory skeleton duration (800ms)
        final elapsed = DateTime.now().difference(startTime);
        final minDuration = widget.disableAnimations ? Duration.zero : const Duration(milliseconds: 800);
        
        if (elapsed < minDuration) {
          Future.delayed(minDuration - elapsed, () {
            if (mounted) setState(() => _isLoading = false);
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  Future<void> _refreshData() async {
    final families = await widget.attendanceRepository.fetchFamilies();
    final sessions = await widget.sessionRepository.loadSessions();
    if (mounted) {
      setState(() {
        _families = families;
        _members = families.expand((f) => f.members).toList();
        _sessions = sessions;
      });
      debugPrint('DEBUG: HubAttendanceView._refreshData: loaded ${_members.length} members and ${_sessions.length} sessions');
    }
  }

  List<Family> _familiesForEvent(Event event) {
    final eventIds = event.memberIds.toSet();
    final result = <Family>[];
    for (final family in _families) {
      final filtered = family.members
          .where((m) => eventIds.contains(m.id))
          .toList();
      if (filtered.isEmpty) continue;
      result.add(family.copyWith(members: filtered));
    }
    return result;
  }

  bool _isEventToday(Event event) {
    final now = DateTime.now();
    final dayName = DateFormat('EEEE').format(now);

    if (event.frequency == 'One-time') {
      return event.oneTimeDate != null &&
          event.oneTimeDate!.year == now.year &&
          event.oneTimeDate!.month == now.month &&
          event.oneTimeDate!.day == now.day;
    }
    
    final isToday = event.repeatingDays.any((d) => d.toLowerCase() == dayName.toLowerCase());
    return isToday;
  }

  void _showEventMenu(BuildContext context, Event event) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Manage Members'),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MembersPage(
                    event: event,
                    attendanceRepository: widget.attendanceRepository,
                    eventRepository: widget.eventRepository,
                    disableAnimations: widget.disableAnimations,
                  ),
                ),
              );
              _refreshData();
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('View History'),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventHistoryPage(
                    event: event,
                    sessionRepository: widget.sessionRepository,
                    attendanceRepository: widget.attendanceRepository,
                    eventRepository: widget.eventRepository,
                    driveService: widget.driveService,
                    disableAnimations: widget.disableAnimations,
                  ),
                ),
              );
              _refreshData();
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit Event'),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEventPage(
                    eventRepository: widget.eventRepository,
                    sessionRepository: widget.sessionRepository,
                    eventToEdit: event,
                    disableAnimations: widget.disableAnimations,
                  ),
                ),
              );
              _refreshData();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete Event', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Event'),
                  content: Text('Are you sure you want to delete "${event.title}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await widget.eventRepository.deleteEvent(event.id);
                if (mounted) Navigator.pop(context);
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _createNewSession() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEventPage(
          eventRepository: widget.eventRepository,
          sessionRepository: widget.sessionRepository,
          disableAnimations: widget.disableAnimations,
        ),
      ),
    );
    _refreshData();
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          themeController: widget.themeController,
          driveService: widget.driveService!,
          localBackupService: widget.localBackupService!,
          attendanceRepository: widget.attendanceRepository,
          eventRepository: widget.eventRepository,
          sessionRepository: widget.sessionRepository,
          appLockController: widget.appLockController,
          disableAnimations: widget.disableAnimations,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshData();
          _subscribeToData();
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              centerTitle: false,
              titleSpacing: 20,
              toolbarHeight: 72,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ConvEyebrow(
                    DateFormat('EEEE · MMM d').format(DateTime.now()),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Today',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: context.conv.ink,
                      fontSize: 30,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _navigateToSettings,
                  tooltip: 'Settings',
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _isLoading 
                ? SliverList(
                    key: const ValueKey('hub_skeleton'),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _EventCardSkeleton(disableAnimations: widget.disableAnimations),
                      ),
                      childCount: 3,
                    ),
                  )
                : _buildEventList(colorScheme),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('hub_fab'),
        heroTag: widget.disableAnimations ? null : 'fab',
        onPressed: _createNewSession,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: const Icon(Icons.add, size: 24),
      ),
    );
  }

  Widget _buildEventList(ColorScheme colorScheme) {
    if (_events.isEmpty) {
      final c = context.conv;
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '0',
                      style: AppTypography.displayNumber(
                        fontSize: 180,
                        color: c.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    ConvEyebrow('Events', color: c.ink3),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nothing on the calendar yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 280,
                child: Text(
                  'Create your first event to start taking attendance. It only takes a moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: c.ink2, height: 1.5),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _createNewSession,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New event'),
              ),
            ],
          ),
        ),
      );
    }

    final sortedEvents = List<Event>.from(_events)..sort((a, b) {
      final aToday = _isEventToday(a);
      final bToday = _isEventToday(b);
      if (aToday != bToday) return aToday ? -1 : 1;
      final aMinutes = a.time.hour * 60 + a.time.minute;
      final bMinutes = b.time.hour * 60 + b.time.minute;
      return aMinutes.compareTo(bMinutes);
    });

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final event = sortedEvents[index];
        final isToday = _isEventToday(event);

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final lastSupposed = getLastSupposedOccurrence(event, now);

        final eventSessions = _sessions.where((s) {
          if (s.eventId != null && s.eventId!.isNotEmpty) {
            return s.eventId == event.id;
          }
          return s.title.trim() == event.title.trim();
        }).toList();
        eventSessions.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));

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
        final displayDate = targetSession?.sessionDate ?? lastSupposed;

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
              attendanceStatus = 'Taken';
            } else {
              attendanceStatus = 'Start';
              isActionable = true;
            }
          } else {
            final dateStr = DateFormat('MMM d').format(displayDate);
            if (hasSession) {
              attendanceStatus = 'Taken ($dateStr)';
            } else {
              attendanceStatus = 'Start';
              isActionable = true;
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _EventCard(
            event: event,
            isToday: isToday,
            attendanceStatus: attendanceStatus,
            isActionable: isActionable,
            onTap: () async {
              debugPrint('DEBUG: HubAttendanceView.onTap("${event.title}") START');
              final targetDate = calculateTargetDate(event, DateTime.now());
              
              final eventSessionsOnTap = _sessions.where((s) {
                if (s.eventId != null && s.eventId!.isNotEmpty) {
                  return s.eventId == event.id;
                }
                return s.title.trim() == event.title.trim();
              }).toList();
              eventSessionsOnTap.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));

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

              final sessionMembers = event.memberIds.isNotEmpty
                  ? _members
                      .where((m) => event.memberIds.contains(m.id))
                      .toList()
                  : <Member>[];
              debugPrint('DEBUG: HubAttendanceView.onTap: foundSession=${foundSession?.id}, membersCount=${sessionMembers.length}');

              if (sessionMembers.isEmpty && foundSession == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please add members to the event before starting attendance.',
                      ),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MembersPage(
                        event: event,
                        attendanceRepository: widget.attendanceRepository,
                        eventRepository: widget.eventRepository,
                        disableAnimations: widget.disableAnimations,
                      ),
                    ),
                  );
                  _refreshData();
                }
                return;
              }

              final sessionFamilies = _familiesForEvent(event);

              if (foundSession != null) {
                final bool isIncomplete = foundSession.records.length < sessionMembers.length;

                if (isIncomplete) {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AttendanceDeckPage(
                        session: foundSession!,
                        members: sessionMembers,
                        families: sessionFamilies,
                        sessionRepository: widget.sessionRepository,
                        attendanceRepository: widget.attendanceRepository,
                        eventRepository: widget.eventRepository,
                        event: event,
                        driveService: widget.driveService,
                        disableAnimations: widget.disableAnimations,
                      ),
                    ),
                  );
                } else {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SessionSummaryPage(
                        session: foundSession!,
                        members: sessionMembers,
                        families: sessionFamilies,
                        sessionRepository: widget.sessionRepository,
                        attendanceRepository: widget.attendanceRepository,
                        eventRepository: widget.eventRepository,
                        event: event,
                        disableAnimations: widget.disableAnimations,
                      ),
                    ),
                  );
                }
              } else {
                final pickedMode = await showStartModePicker(
                  context,
                  initial: event.defaultAttendanceStartMode,
                );
                if (pickedMode == null) return;
                if (!context.mounted) return;

                if (event.defaultAttendanceStartMode != pickedMode) {
                  final updatedEvent = event.copyWith(
                    defaultAttendanceStartMode: pickedMode,
                    updatedAt: DateTime.now(),
                  );
                  try {
                    await widget.eventRepository.updateEvent(updatedEvent);
                  } catch (e) {
                    debugPrint('Error saving start mode preference: $e');
                  }
                  if (!context.mounted) return;
                }

                List<Session> recentSessions = const [];
                if (pickedMode == AttendanceStartMode.perMemberDefault) {
                  try {
                    final all = await widget.sessionRepository.loadSessions();
                    all.sort((a, b) =>
                        b.sessionDate.compareTo(a.sessionDate));
                    recentSessions = all;
                  } catch (e) {
                    debugPrint('Error loading session history: $e');
                  }
                  if (!context.mounted) return;
                }

                final preseed = buildPreseededRecords(
                  members: sessionMembers,
                  mode: pickedMode,
                  recordedAt: DateTime.now(),
                  recentSessions: recentSessions,
                  recordedBy: pickedMode == AttendanceStartMode.perMemberDefault
                      ? 'System (Preseed - Smart)'
                      : 'System (Preseed)',
                );

                final session = await widget.sessionRepository.createSession(
                  title: event.title,
                  eventId: event.id,
                  sessionDate: targetDate,
                  actor: 'User',
                  records: preseed,
                );

                if (!context.mounted) return;

                var resultSession = await Navigator.of(context).push<Session>(
                  MaterialPageRoute(
                    builder: (_) => AttendanceDeckPage(
                      session: session,
                      members: sessionMembers,
                      families: sessionFamilies,
                      sessionRepository: widget.sessionRepository,
                      attendanceRepository: widget.attendanceRepository,
                      eventRepository: widget.eventRepository,
                      event: event,
                      driveService: widget.driveService,
                      disableAnimations: widget.disableAnimations,
                    ),
                  ),
                );

                resultSession ??= await widget.sessionRepository.findSessionById(session.id);

                final preseedKeys = preseed
                    .map((r) => r.memberId ?? r.attendee)
                    .toSet();
                final hasUserEdits = resultSession != null &&
                    resultSession.records.any((r) {
                      final key = r.memberId ?? r.attendee;
                      if (!preseedKeys.contains(key)) return true;
                      return r.recordedBy != 'System (Preseed)';
                    });

                if (resultSession != null && !hasUserEdits) {
                  await widget.sessionRepository.deleteSession(
                    session.id,
                    actor: 'System (Cleanup)',
                  );
                }
              }
              _refreshData();
            },
            onMenuTap: () => _showEventMenu(context, event),
            primaryColor: colorScheme.primary,
            onPrimaryColor: colorScheme.onPrimary,
            surfaceContainerColor: colorScheme.surfaceContainer,
            onSurfaceColor: colorScheme.onSurface,
            onSurfaceVariantColor: colorScheme.onSurfaceVariant,
            secondaryContainerColor: colorScheme.secondaryContainer,
            onSecondaryContainerColor: colorScheme.onSecondaryContainer,
            disableAnimations: widget.disableAnimations,
          ),
        );
      }, childCount: sortedEvents.length),
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
      'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
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
    } else if (status.contains('Taken')) {
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
              status.toUpperCase(),
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
                              final opacity = 1.0 - (_pulseController.value / 0.7).clamp(0.0, 1.0);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: widget.primaryColor,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.primaryColor.withOpacity(opacity * 0.4),
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
                              Flexible(
                                child: Text(
                                  widget.event.oneTimeDate != null
                                      ? DateFormat('EEEE, MMM d, yyyy').format(widget.event.oneTimeDate!)
                                      : 'One-time Event',
                                  style: TextStyle(
                                    color: widget.onSurfaceVariantColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
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
                    icon: Icon(Icons.more_vert, color: widget.onSurfaceVariantColor),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 20, color: widget.onSurfaceVariantColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          widget.event.time.format(context),
                          style: TextStyle(
                            fontSize: 18,
                            color: widget.onSurfaceVariantColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: _buildAttendanceStatusPill(widget.attendanceStatus),
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
                          AppShimmer(
                            width: 60,
                            height: 24,
                            borderRadius: BorderRadius.circular(28),
                            disableAnimations: disableAnimations,
                          ),
                          const SizedBox(width: 8),
                          AppShimmer(
                            width: 80,
                            height: 24,
                            borderRadius: BorderRadius.circular(28),
                            disableAnimations: disableAnimations,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppShimmer(
                        width: 200,
                        height: 32,
                        disableAnimations: disableAnimations,
                      ),
                      const SizedBox(height: 8),
                      AppShimmer(
                        width: 140,
                        height: 32,
                        disableAnimations: disableAnimations,
                      ),
                    ],
                  ),
                ),
                AppShimmer(
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
                    AppShimmer(
                      width: 20,
                      height: 20,
                      disableAnimations: disableAnimations,
                    ),
                    const SizedBox(width: 8),
                    AppShimmer(
                      width: 60,
                      height: 20,
                      disableAnimations: disableAnimations,
                    ),
                  ],
                ),
                AppShimmer(
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
