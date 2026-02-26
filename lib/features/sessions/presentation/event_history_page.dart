import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';

import '../../../../data/session.dart';
import '../../../../data/session_repository.dart';
import '../../hub/domain/event.dart';
import '../../attendance/presentation/session_summary_page.dart';
import '../../attendance/models/attendance_status.dart';

class EventHistoryPage extends StatefulWidget {
  const EventHistoryPage({
    super.key,
    required this.event,
    required this.sessionRepository,
    required this.attendanceRepository,
  });

  final Event event;
  final SessionRepository sessionRepository;
  final AttendanceRepository attendanceRepository;

  @override
  State<EventHistoryPage> createState() => _EventHistoryPageState();
}

class _EventHistoryPageState extends State<EventHistoryPage> {
  late Stream<List<Session>> _sessionsStream;
  bool _isLoading = true;
  List<Member> _members = [];

  @override
  void initState() {
    super.initState();
    _sessionsStream = widget.sessionRepository.streamSessions();
    _loadData();
  }

  Future<void> _loadData() async {
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

    // Minimum loading duration for visual consistency
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      setState(() => _isLoading = false);
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
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: RepaintBoundary(
        child: RefreshIndicator(
          onRefresh: () async {
            await widget.sessionRepository.refresh();
            await widget.attendanceRepository.refresh();
            await _loadData();
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: _isLoading 
              ? _buildSkeleton(context)
              : StreamBuilder<List<Session>>(
                stream: _sessionsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return _buildSkeleton(context);
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final allSessions = snapshot.data ?? [];
                  final eventSessions = allSessions.where((s) => s.title == widget.event.title).toList();

                  // Sort by date descending
                  eventSessions.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));

                  if (eventSessions.isEmpty) {
                    return LayoutBuilder(
                      builder: (context, constraints) => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          Container(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history_outlined,
                                    size: 64,
                                    color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No history found',
                                    style: TextStyle(color: colorScheme.onSurfaceVariant),
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
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final session = eventSessions[index];
                      final dateStr = DateFormat('MMM d, yyyy').format(session.sessionDate);
                      final dayTimeStr = '${DateFormat('EEEE').format(session.sessionDate)} • ${widget.event.time.format(context)}';

                      final presentCount = session.records.where((r) => r.status == AttendanceStatus.present).length;
                      final absentCount = session.records.where((r) => r.status == AttendanceStatus.absent).length;

                      return Card(
                        elevation: 0,
                        color: colorScheme.secondaryContainer.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SessionSummaryPage(
                                  session: session,
                                  members: _members,
                                  sessionRepository: widget.sessionRepository,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dateStr,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                        Text(
                                          dayTimeStr,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildStatusBadge(
                                      context,
                                      Icons.check_circle,
                                      colorScheme.primary,
                                      '$presentCount Present',
                                    ),
                                    Container(
                                      height: 16,
                                      width: 1,
                                      margin: const EdgeInsets.symmetric(horizontal: 16),
                                      color: colorScheme.outlineVariant,
                                    ),
                                    _buildStatusBadge(
                                      context,
                                      Icons.cancel,
                                      colorScheme.error,
                                      '$absentCount Absent',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ),
        ),
      ),
    );
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
          height: 120,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 180,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 32),
                  Container(
                    width: 80,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
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
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
