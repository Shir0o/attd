import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/event_repository.dart';
import '../domain/event.dart';
import 'add_event_page.dart';
import '../../attendance/data/attendance_repository.dart';
import 'members_page.dart';

class HubAttendanceView extends StatefulWidget {
  const HubAttendanceView({
    super.key,
    required this.eventRepository,
    required this.attendanceRepository,
    this.onSignOut,
  });

  final EventRepository eventRepository;
  final AttendanceRepository attendanceRepository;
  final VoidCallback? onSignOut;

  @override
  State<HubAttendanceView> createState() => _HubAttendanceViewState();
}

class _HubAttendanceViewState extends State<HubAttendanceView> {
  // Using Stream for real-time updates
  late Stream<List<Event>> _eventsStream;

  @override
  void initState() {
    super.initState();
    _eventsStream = widget.eventRepository.streamEvents();
  }

  void _createNewSession() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEventPage(eventRepository: widget.eventRepository),
      ),
    );
  }

  void _editEvent(Event event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEventPage(
          eventRepository: widget.eventRepository,
          eventToEdit: event,
        ),
      ),
    );
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

  void _showEventMenu(BuildContext context, Event event) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
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
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Event'),
                onTap: () {
                  Navigator.pop(context); // Close sheet
                  _editEvent(event);
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Manage Members'),
                onTap: () {
                  Navigator.pop(context); // Close sheet
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MembersPage(
                        attendanceRepository: widget.attendanceRepository,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Event',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context); // Close sheet
                  _deleteEvent(event);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    // Stitch Colors
    const primaryColor = Color(0xFF6750A4);
    const onPrimaryColor = Color(0xFFFFFFFF);
    const surfaceColor = Color(0xFFFEF7FF);
    const onSurfaceColor = Color(0xFF1D1B20);
    const onSurfaceVariantColor = Color(0xFF49454F);
    const surfaceContainerColor = Color(0xFFF3EDF7);
    const secondaryContainerColor = Color(0xFFE8DEF8);
    const onSecondaryContainerColor = Color(0xFF1D192B);

    return Scaffold(
      backgroundColor: surfaceColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: surfaceColor,
            floating: true,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TODAY',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: onSurfaceVariantColor,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  DateFormat('EEE, MMM d').format(DateTime.now()).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: onSurfaceColor,
                  ),
                ),
              ],
            ),
            actions: [
              if (widget.onSignOut != null)
                IconButton(
                  icon: const Icon(Icons.logout, color: onSurfaceVariantColor),
                  onPressed: widget.onSignOut,
                ),
            ],
            expandedHeight: 100,
            toolbarHeight: 80,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: StreamBuilder<List<Event>>(
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
                        style: TextStyle(color: onSurfaceVariantColor),
                      ),
                    ),
                  );
                }

                // Sort events: Today's events first
                final events = snapshot.data!;
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

                final sortedEvents = [...todayEvents, ...otherEvents];

                return SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final event = sortedEvents[index];
                    final isToday = _isEventToday(event);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _EventCard(
                        event: event,
                        isToday: isToday,
                        onTap: () {
                          // TODO: Handle event tap (view details)
                        },
                        onMenuTap: () => _showEventMenu(context, event),
                        primaryColor: primaryColor,
                        onPrimaryColor: onPrimaryColor,
                        surfaceContainerColor: surfaceContainerColor,
                        onSurfaceColor: onSurfaceColor,
                        onSurfaceVariantColor: onSurfaceVariantColor,
                        secondaryContainerColor: secondaryContainerColor,
                        onSecondaryContainerColor: onSecondaryContainerColor,
                      ),
                    );
                  }, childCount: sortedEvents.length),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewSession,
        backgroundColor: primaryColor,
        foregroundColor: onPrimaryColor,
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
                                    fontSize: 12,
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
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 20,
                          color: onSurfaceVariantColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            event.time.format(context),
                            style: TextStyle(
                              fontSize: 18,
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
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isToday
                          ? secondaryContainerColor
                          : surfaceContainerColor.withAlpha(
                              20,
                            ), // Less prominent
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: onSurfaceVariantColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '0/0 Scanned',
                            style: TextStyle(
                              fontSize: 14,
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
