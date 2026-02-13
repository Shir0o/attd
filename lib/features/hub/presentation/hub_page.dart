import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/session.dart';
import '../../../../data/session_repository.dart';
import '../../attendance/models/attendance_status.dart';
import '../../sessions/session_detail_page.dart';

class HubPage extends StatefulWidget {
  const HubPage({super.key, required this.sessionRepository, this.onSignOut});

  final SessionRepository sessionRepository;
  final VoidCallback? onSignOut;

  @override
  State<HubPage> createState() => _HubPageState();
}

class _HubPageState extends State<HubPage> {
  late Future<List<Session>> _sessionsFuture;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    // In a real app, we'd filter by date in the repository
    _sessionsFuture = widget.sessionRepository.loadSessions().then((sessions) {
      // Filter for selected date (ignoring time)
      return sessions.where((s) {
        return isSameDay(s.sessionDate, _selectedDate);
      }).toList();
    });
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _loadSessions();
      });
    }
  }

  void _openSession(Session session) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionDetailPage(
          session: session,
          repository: widget.sessionRepository,
        ),
      ),
    );
    setState(() {
      _loadSessions();
    });
  }

  // Placeholder for creating a new session
  void _createNewSession() {
    // TODO: Implement create session flow or navigation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create Session not implemented yet')),
    );
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
                Text(
                  isSameDay(_selectedDate, DateTime.now())
                      ? 'TODAY'
                      : DateFormat('EEEE').format(_selectedDate).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: onSurfaceVariantColor,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  DateFormat('EEE, MMM d').format(_selectedDate).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: onSurfaceColor,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.calendar_today,
                  color: onSurfaceVariantColor,
                ),
                onPressed: _selectDate,
              ),
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
            sliver: FutureBuilder<List<Session>>(
              future: _sessionsFuture,
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
                        'No sessions for this day',
                        style: TextStyle(color: onSurfaceVariantColor),
                      ),
                    ),
                  );
                }

                final sessions = snapshot.data!;
                return SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final session = sessions[index];
                    // Calculate stats
                    // Actually based on previous code, records are attendance records.
                    // Stitch UI says "0/45 Scanned".
                    // If 'records' only contains people who scanned/are marked, we might need a total count from somewhere else (like a Group or Family list).
                    // For now, let's assume 'records' is the list of everyone expected?
                    // Looking at SessionRecord, it has AttendanceStatus.
                    final scannedCount = session.records
                        .where((r) => r.status == AttendanceStatus.present)
                        .length;

                    // Check if "LIVE" (e.g. within 1 hour of start time) - Simplified logic
                    final isLive =
                        session.sessionDate.isBefore(DateTime.now()) &&
                        session.sessionDate
                            .add(const Duration(hours: 2))
                            .isAfter(DateTime.now());

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _SessionCard(
                        session: session,
                        scannedCount: scannedCount,
                        totalCount: session
                            .records
                            .length, // Or some other metric if available
                        isLive: isLive,
                        onTap: () => _openSession(session),
                        primaryColor: primaryColor,
                        onPrimaryColor: onPrimaryColor,
                        surfaceContainerColor: surfaceContainerColor,
                        onSurfaceColor: onSurfaceColor,
                        onSurfaceVariantColor: onSurfaceVariantColor,
                        secondaryContainerColor: secondaryContainerColor,
                        onSecondaryContainerColor: onSecondaryContainerColor,
                      ),
                    );
                  }, childCount: sessions.length),
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

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.scannedCount,
    required this.totalCount,
    required this.isLive,
    required this.onTap,
    required this.primaryColor,
    required this.onPrimaryColor,
    required this.surfaceContainerColor,
    required this.onSurfaceColor,
    required this.onSurfaceVariantColor,
    required this.secondaryContainerColor,
    required this.onSecondaryContainerColor,
  });

  final Session session;
  final int scannedCount;
  final int totalCount;
  final bool isLive;
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
      elevation:
          0, // Manually handling shadow if needed, or use default elevation
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
                        if (isLive)
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
                                  'LIVE',
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
                          const SizedBox(
                            height: 26 + 8,
                          ), // Placeholder to align titles if needed, or remove

                        Text(
                          session.title,
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
                    onPressed: () {
                      // TODO: Implement more options
                    },
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
                        DateFormat.jm().format(session.sessionDate),
                        style: TextStyle(
                          fontSize: 18,
                          color: onSurfaceVariantColor,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isLive
                          ? secondaryContainerColor
                          : surfaceContainerColor, // Slightly different if live vs not? Stitch uses secondary for live
                      borderRadius: BorderRadius.circular(28),
                      // border: Border.all(color: onSurfaceVariantColor.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$scannedCount/$totalCount Scanned',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: onSecondaryContainerColor,
                          ),
                        ),
                        if (isLive) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: primaryColor, width: 2),
                            ),
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
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
