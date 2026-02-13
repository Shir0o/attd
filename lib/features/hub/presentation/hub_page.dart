import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/session_repository.dart';
import '../data/event_repository.dart';
import '../domain/event.dart';
import 'add_event_page.dart';

class HubPage extends StatefulWidget {
  const HubPage({
    super.key,
    required this.sessionRepository,
    required this.eventRepository,
    this.onSignOut,
  });

  final SessionRepository sessionRepository;
  final EventRepository eventRepository;
  final VoidCallback? onSignOut;

  @override
  State<HubPage> createState() => _HubPageState();
}

class _HubPageState extends State<HubPage> {
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
                          // TODO: Handle event tap (edit/view)
                        },
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
          height: 200,
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: onSurfaceVariantColor),
                    onPressed: () {},
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 20,
                        color: onSurfaceVariantColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        event.time.format(context),
                        style: TextStyle(
                          fontSize: 18,
                          color: onSurfaceVariantColor,
                        ),
                      ),
                    ],
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
                      children: [
                        Text(
                          '0/0 Scanned',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: onSurfaceVariantColor,
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
