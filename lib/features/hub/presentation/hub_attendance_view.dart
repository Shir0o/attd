import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/design/app_radii.dart';
import '../../../core/design/app_shadows.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../../../data/session.dart';
import '../../../data/session_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/attendance_status.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';
import '../../attendance/presentation/attendance_deck_page.dart';
import '../../attendance/presentation/session_summary_page.dart';
import '../../attendance/models/attendance_start_mode.dart';
import '../../attendance/presentation/grouping_preset_picker.dart';
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
    _dataSubscription =
        widget.eventRepository.streamEvents().listen((events) async {
      final sessions = await widget.sessionRepository.loadSessions();

      if (mounted) {
        setState(() {
          _events = events;
          _sessions = sessions;
        });

        // Mandatory skeleton duration (800ms)
        final elapsed = DateTime.now().difference(startTime);
        final minDuration = widget.disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 800);

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
      debugPrint(
          'DEBUG: HubAttendanceView._refreshData: loaded ${_members.length} members and ${_sessions.length} sessions');
    }
  }

  List<Family> _familiesForEvent(Event event) {
    final eventIds = event.memberIds.toSet();
    final result = <Family>[];
    for (final family in _families) {
      final filtered =
          family.members.where((m) => eventIds.contains(m.id)).toList();
      if (filtered.isEmpty) continue;
      result.add(family.copyWith(members: filtered));
    }
    return result;
  }

  int get _todayEventCount => _events.where(_isEventToday).length;

  bool _isEventToday(Event event) {
    final now = DateTime.now();
    final dayName = DateFormat('EEEE').format(now);

    if (event.frequency == 'One-time') {
      return event.oneTimeDate != null &&
          event.oneTimeDate!.year == now.year &&
          event.oneTimeDate!.month == now.month &&
          event.oneTimeDate!.day == now.day;
    }

    final isToday = event.repeatingDays
        .any((d) => d.toLowerCase() == dayName.toLowerCase());
    return isToday;
  }

  List<Session> _sessionsForEvent(Event event) => _sessions.where((s) {
        if (s.eventId != null && s.eventId!.isNotEmpty) {
          return s.eventId == event.id;
        }
        return s.title.trim() == event.title.trim();
      }).toList();

  /// Resolves the headline status of an event for display on the hub.
  _EventStatus _statusFor(Event event) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastSupposed = getLastSupposedOccurrence(event, now);

    final eventSessions = _sessionsForEvent(event)
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));

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

    String label;
    bool actionable = false;

    if (lastSupposed.isAfter(today)) {
      label = 'Upcoming';
    } else {
      final isTargetToday = displayDate.year == today.year &&
          displayDate.month == today.month &&
          displayDate.day == today.day;
      if (isTargetToday) {
        if (hasSession) {
          label = 'Taken';
        } else {
          label = 'Start';
          actionable = true;
        }
      } else {
        final dateStr = DateFormat('MMM d').format(displayDate);
        if (hasSession) {
          label = 'Taken ($dateStr)';
        } else {
          label = 'Start';
          actionable = true;
        }
      }
    }

    return _EventStatus(
      label: label,
      actionable: actionable,
      taken: hasSession,
      displayDate: displayDate,
      presentCount: targetSession?.records
          .where((r) => r.status == AttendanceStatus.present)
          .length,
    );
  }

  /// Present count / total of the most recent session that occurred before
  /// today — drives the "Last week" stat on the hero card.
  ({int present, int total})? _lastSessionStat(Event event) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final past = _sessionsForEvent(event).where((s) {
      final d = DateTime(
        s.sessionDate.year,
        s.sessionDate.month,
        s.sessionDate.day,
      );
      return d.isBefore(today);
    }).toList()
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
    if (past.isEmpty) return null;
    final s = past.first;
    final present =
        s.records.where((r) => r.status == AttendanceStatus.present).length;
    return (present: present, total: s.records.length);
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
            title:
                const Text('Delete Event', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Event'),
                  content:
                      Text('Are you sure you want to delete "${event.title}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'Today',
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(color: context.conv.ink, fontSize: 30),
                      ),
                      if (_todayEventCount > 1) ...[
                        const SizedBox(width: 10),
                        ConvPill(
                          label: '$_todayEventCount EVENTS',
                          isOn: true,
                          fontSize: 10,
                          letterSpacing: 1.0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                        ),
                      ],
                    ],
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
                          child: _EventCardSkeleton(
                              disableAnimations: widget.disableAnimations),
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

    int byTime(Event a, Event b) {
      final aMinutes = a.time.hour * 60 + a.time.minute;
      final bMinutes = b.time.hour * 60 + b.time.minute;
      return aMinutes.compareTo(bMinutes);
    }

    // Single pass so the (relatively expensive) _isEventToday check runs once
    // per event rather than twice.
    final todayEvents = <Event>[];
    final otherEvents = <Event>[];
    for (final event in _events) {
      (_isEventToday(event) ? todayEvents : otherEvents).add(event);
    }
    todayEvents.sort(byTime);
    otherEvents.sort(byTime);

    final c = context.conv;
    final children = <Widget>[];

    // The highlight card is reserved for a single today event — the soonest
    // one still needing attendance (or the soonest, if all are taken).
    Event? hero;
    if (todayEvents.isNotEmpty) {
      final currentHero = todayEvents.firstWhere(
        (e) => !_statusFor(e).taken,
        orElse: () => todayEvents.first,
      );
      hero = currentHero;

      children.add(
        _HeroEventCard(
          event: currentHero,
          isToday: true,
          status: _statusFor(currentHero),
          expected: currentHero.memberIds.length,
          lastStat: _lastSessionStat(currentHero),
          onTap: () => _handleEventTap(currentHero),
          onMenuTap: () => _showEventMenu(context, currentHero),
          disableAnimations: widget.disableAnimations,
        ),
      );

      // "Also today" — the remaining same-day events, so they don't get
      // buried in the weekly list.
      final alsoToday = todayEvents.where((e) => e != currentHero).toList();
      if (alsoToday.isNotEmpty) {
        final doneCount = alsoToday.where((e) => _statusFor(e).taken).length;
        final laterCount = alsoToday.length - doneCount;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 28, bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const ConvEyebrow('Also today'),
                ConvEyebrow(
                  '$laterCount later${doneCount > 0 ? ' · $doneCount done' : ''}',
                  color: c.ink4,
                ),
              ],
            ),
          ),
        );
        for (final event in alsoToday) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TodayRow(
                event: event,
                status: _statusFor(event),
                expected: event.memberIds.length,
                onTap: () => _handleEventTap(event),
                onMenuTap: () => _showEventMenu(context, event),
              ),
            ),
          );
        }
      }
    }

    // Non-today events. Labelled "This week" when a hero is present, else the
    // standalone "Upcoming" section.
    if (otherEvents.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ConvEyebrow(hero != null ? 'This week' : 'Upcoming'),
              ConvEyebrow(
                hero != null
                    ? '${otherEvents.length} · upcoming'
                    : '${otherEvents.length} · this week',
                color: c.ink4,
              ),
            ],
          ),
        ),
      );
      for (final event in otherEvents) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EventRow(
              event: event,
              isToday: false,
              status: _statusFor(event),
              onTap: () => _handleEventTap(event),
              onMenuTap: () => _showEventMenu(context, event),
            ),
          ),
        );
      }
    }

    return SliverList(delegate: SliverChildListDelegate(children));
  }

  Future<void> _handleEventTap(Event event) async {
    final context = this.context;
    debugPrint('DEBUG: HubAttendanceView.onTap("${event.title}") START');
    final targetDate = calculateTargetDate(event, DateTime.now());

    final eventSessionsOnTap = _sessionsForEvent(event)
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));

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
        ? _members.where((m) => event.memberIds.contains(m.id)).toList()
        : <Member>[];
    debugPrint(
        'DEBUG: HubAttendanceView.onTap: foundSession=${foundSession?.id}, membersCount=${sessionMembers.length}');

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

    // First time taking attendance for this event: ask how to group the
    // roster. The choice is saved on the event and inherited next time; it can
    // be changed later in the event editor ("Group roster by").
    if (event.rosterGrouping == null) {
      final picked = await showGroupingPresetPicker(context);
      if (picked == null) return;
      if (!context.mounted) return;
      event = event.copyWith(
        rosterGrouping: picked,
        updatedAt: DateTime.now(),
      );
      try {
        await widget.eventRepository.updateEvent(event);
      } catch (e) {
        debugPrint('Error saving grouping preset: $e');
      }
      if (!context.mounted) return;
    }

    final sessionFamilies = _familiesForEvent(event);

    if (foundSession != null) {
      // A session that exists here is always a confirmed/"Taken" session, so
      // tapping the card opens the summary (where individual statuses can still
      // be edited) rather than reopening the marking deck.
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
          all.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
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

      await Navigator.of(context).push<Session>(
        MaterialPageRoute(
          builder: (_) => AttendanceDeckPage(
            session: session,
            deleteOnCancel: true,
            members: sessionMembers,
            families: sessionFamilies,
            sessionRepository: widget.sessionRepository,
            attendanceRepository: widget.attendanceRepository,
            eventRepository: widget.eventRepository,
            event: event,
            driveService: widget.driveService,
            disableAnimations: widget.disableAnimations,
            // "All present" and smart defaults open directly in the roster
            // List view so the user toggles exceptions; "all absent" keeps
            // the speed-swipe deck.
            initialListMode: pickedMode != AttendanceStartMode.allAbsent,
            startMode: pickedMode,
            rosterGrouping: event.rosterGrouping,
          ),
        ),
      );

      // Keeping vs discarding the session is decided inside the deck: cancelling
      // (X / system back) discards it, confirming (Done → summary) keeps it.
    }
    _refreshData();
  }
}

/// Resolved display status for an event on the hub.
class _EventStatus {
  const _EventStatus({
    required this.label,
    required this.actionable,
    required this.taken,
    required this.displayDate,
    this.presentCount,
  });

  final String label;
  final bool actionable;
  final bool taken;
  final DateTime displayDate;

  /// Number of present attendees in the marked session, when [taken] is true.
  final int? presentCount;
}

/// The large editorial "Up next" card — the first/soonest event on the hub.
class _HeroEventCard extends StatefulWidget {
  const _HeroEventCard({
    required this.event,
    required this.isToday,
    required this.status,
    required this.expected,
    required this.lastStat,
    required this.onTap,
    required this.onMenuTap,
    this.disableAnimations = false,
  });

  final Event event;
  final bool isToday;
  final _EventStatus status;
  final int expected;
  final ({int present, int total})? lastStat;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;
  final bool disableAnimations;

  @override
  State<_HeroEventCard> createState() => _HeroEventCardState();
}

class _HeroEventCardState extends State<_HeroEventCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isToday && !widget.disableAnimations) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _HeroEventCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldAnimate = widget.isToday && !widget.disableAnimations;
    final wasAnimating = oldWidget.isToday && !oldWidget.disableAnimations;
    if (shouldAnimate && !wasAnimating) {
      _pulseController.repeat();
    } else if (!shouldAnimate && wasAnimating) {
      _pulseController
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  static const _dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final time = widget.event.time.format(context);
    final pillLabel = widget.isToday
        ? 'TODAY · $time'
        : '${DateFormat('EEE').format(widget.status.displayDate).toUpperCase()} · $time';

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadii.cardR,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: c.card,
        borderRadius: AppRadii.cardR,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Stack(
            children: [
              // Decorative serif glyph, bleeding off the bottom-right.
              Positioned(
                right: -20,
                bottom: -64,
                child: IgnorePointer(
                  child: Text(
                    '§',
                    style: AppTypography.fraunces(
                      fontSize: 200,
                      fontWeight: FontWeight.w400,
                      color: c.primary.withValues(alpha: 0.06),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _PulsePill(
                          label: pillLabel,
                          controller: _pulseController,
                          animate: widget.isToday && !widget.disableAnimations,
                        ),
                        const Spacer(),
                        ConvIconButton(
                          icon: Icons.more_vert,
                          size: 32,
                          iconSize: 20,
                          color: c.ink2,
                          onPressed: widget.onMenuTap,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.fraunces(
                        fontSize: 34,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.68,
                        height: 1.08,
                        color: c.ink,
                      ),
                    ),
                    if (widget.event.frequency == 'One-time' &&
                        widget.event.oneTimeDate != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 14, color: c.ink3),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              DateFormat('EEEE, MMM d, yyyy')
                                  .format(widget.event.oneTimeDate!),
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.geist(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: c.ink3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (widget.event.repeatingDays.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          for (var i = 0; i < 7; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            ConvDayChip(
                              day: _dayLetters[i],
                              active: widget.event.repeatingDays
                                  .contains(_dayNames[i]),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _HeroStat(
                            label: 'Expected',
                            value: '${widget.expected}',
                            color: c.ink,
                          ),
                        ),
                        Expanded(
                          child: _LastWeekStat(stat: widget.lastStat),
                        ),
                        _HeroAction(
                          status: widget.status,
                          onTap: widget.onTap,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsePill extends StatelessWidget {
  const _PulsePill({
    required this.label,
    required this.controller,
    required this.animate,
  });

  final String label;
  final AnimationController controller;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.eyebrow(color: c.onPrimary).copyWith(
          letterSpacing: 1.32,
        ),
      ),
    );
    if (!animate) return pill;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = (controller.value / 0.7).clamp(0.0, 1.0);
        final curveValue = Curves.easeOut.transform(t);
        final opacity = 1.0 - t;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: c.primary.withValues(alpha: opacity * 0.4),
                blurRadius: 0,
                spreadRadius: curveValue * 6,
              ),
            ],
          ),
          child: child,
        );
      },
      child: pill,
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConvEyebrow(label),
        const SizedBox(height: 2),
        Text(value,
            style: AppTypography.displayNumber(fontSize: 28, color: color)),
      ],
    );
  }
}

class _LastWeekStat extends StatelessWidget {
  const _LastWeekStat({required this.stat});

  final ({int present, int total})? stat;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final s = stat;
    if (s == null || s.total == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const ConvEyebrow('Last week'),
          const SizedBox(height: 2),
          Text('—',
              style: AppTypography.displayNumber(fontSize: 28, color: c.ink3)),
        ],
      );
    }
    final pct = ((s.present / s.total) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const ConvEyebrow('Last week'),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${s.present}',
                style:
                    AppTypography.displayNumber(fontSize: 28, color: c.ink2)),
            const SizedBox(width: 4),
            Text('· $pct%',
                style: AppTypography.geist(fontSize: 14, color: c.ink3)),
          ],
        ),
      ],
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({required this.status, required this.onTap});

  final _EventStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    if (status.taken) {
      return ConvPill(
        label: 'Taken',
        leading: const Icon(Icons.check),
        onTap: onTap,
      );
    }
    return Material(
      color: c.primary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Start',
                style: AppTypography.geist(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: c.onPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.play_arrow, size: 18, color: c.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact "Upcoming" row — date numeral, name, time, and status chip.
class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.isToday,
    required this.status,
    required this.onTap,
    required this.onMenuTap,
  });

  final Event event;
  final bool isToday;
  final _EventStatus status;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final date = status.displayDate;
    final dayLabel =
        isToday ? 'TODAY' : DateFormat('EEE').format(date).toUpperCase();
    final dateNum = DateFormat('d').format(date);

    return ConvCardSoft(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                ConvEyebrow(dayLabel),
                Text(
                  dateNum,
                  style:
                      AppTypography.displayNumber(fontSize: 24, color: c.ink),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.geist(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      status.taken ? Icons.check : Icons.schedule,
                      size: 13,
                      color: status.taken ? c.present : c.ink3,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status.taken ? 'Marked' : event.time.format(context),
                      style: AppTypography.geist(
                        fontSize: 12,
                        color: status.taken ? c.present : c.ink3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConvIconButton(
            icon: Icons.more_vert,
            size: 32,
            iconSize: 20,
            color: c.ink4,
            onPressed: onMenuTap,
          ),
        ],
      ),
    );
  }
}

/// Row for a same-day event in the "Also today" group — time-forward left
/// rail with an inline Start / Taken affordance, dimmed once taken.
class _TodayRow extends StatelessWidget {
  const _TodayRow({
    required this.event,
    required this.status,
    required this.expected,
    required this.onTap,
    required this.onMenuTap,
  });

  final Event event;
  final _EventStatus status;
  final int expected;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    // Format the time/marker via DateFormat so the split is locale-safe rather
    // than relying on a space separator that some locales omit.
    final use24Hour = MediaQuery.of(context).alwaysUse24HourFormat;
    final dummyDate = DateTime(2020, 1, 1, event.time.hour, event.time.minute);
    final hh = use24Hour
        ? DateFormat('HH:mm').format(dummyDate)
        : DateFormat('h:mm').format(dummyDate);
    final ampm = use24Hour ? '' : DateFormat('a').format(dummyDate);

    return Opacity(
      opacity: status.taken ? 0.66 : 1,
      child: ConvCardSoft(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  Text(
                    hh,
                    style: AppTypography.displayNumber(
                      fontSize: 19,
                      color: c.ink,
                    ),
                  ),
                  if (ampm.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    ConvEyebrow(ampm),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(width: 1, height: 30, color: c.hair),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.geist(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        status.taken ? Icons.check : Icons.people_outline,
                        size: 13,
                        color: status.taken ? c.present : c.ink3,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.taken
                            ? 'Marked · ${status.presentCount ?? 0} present'
                            : '$expected expected',
                        style: AppTypography.geist(
                          fontSize: 12,
                          color: status.taken ? c.present : c.ink3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConvIconButton(
              icon: Icons.more_vert,
              size: 32,
              iconSize: 20,
              color: c.ink4,
              onPressed: onMenuTap,
            ),
          ],
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
