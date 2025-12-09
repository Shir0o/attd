import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'data/session.dart';
import 'data/session_repository.dart';
import 'features/analytics/attendance_analytics.dart';
import 'features/attendance/data/attendance_repository.dart';
import 'features/attendance/models/attendance_status.dart';
import 'features/attendance/models/family.dart';
import 'features/attendance/presentation/attendance_flow_page.dart';
import 'features/sessions/session_detail_page.dart';

void main() {
  runApp(AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  AttendanceApp({
    super.key,
    AttendanceRepository? repository,
    SessionRepository? sessionRepository,
  }) : repository = repository ?? LocalJsonAttendanceRepository(),
       sessionRepository =
           sessionRepository ??
           LocalSessionRepository(seedSessions: buildSeedSessions());

  final AttendanceRepository repository;
  final SessionRepository sessionRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: AttendanceHomePage(
        repository: repository,
        sessionRepository: sessionRepository,
      ),
    );
  }
}

class AttendanceHomePage extends StatefulWidget {
  const AttendanceHomePage({
    super.key,
    required this.repository,
    required this.sessionRepository,
  });

  final AttendanceRepository repository;
  final SessionRepository sessionRepository;

  @override
  State<AttendanceHomePage> createState() => _AttendanceHomePageState();
}

class _AttendanceHomePageState extends State<AttendanceHomePage> {
  late Future<_HomeData> _homeDataFuture;
  AnalyticsRange _selectedRange = AnalyticsRange.last30Days;

  @override
  void initState() {
    super.initState();
    _homeDataFuture = _loadHomeData();
  }

  Future<_HomeData> _loadHomeData() async {
    final sessions = await widget.sessionRepository.loadSessions();
    final families = await widget.repository.fetchFamilies();
    return _HomeData(sessions: sessions, families: families);
  }

  void _startAttendanceFlow(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceFlowPage(repository: widget.repository),
      ),
    );
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
      _homeDataFuture = _loadHomeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _homeDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final homeData = snapshot.data ?? const _HomeData();
        final range = _selectedRange.resolve(DateTime.now());
        final analytics = calculateAttendanceAnalytics(
          sessions: homeData.sessions,
          families: homeData.families,
          range: range,
        );

        final breakdown = analytics.breakdown;
        final attendanceRate = breakdown.rate.round();
        final maxAbsenceStreak = analytics.attendees.values
            .fold<int>(0, (previous, element) => math.max(previous, element.absenceStreak));
        final latestTrend = analytics.trend.isNotEmpty
            ? analytics.trend.last.toStringAsFixed(0)
            : '0';

        return Scaffold(
          appBar: AppBar(title: const Text('Attendance Tracker')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _homeDataFuture = _loadHomeData();
                });
                await _homeDataFuture;
              },
              child: ListView(
                children: [
                  Text(
                    'Engagement overview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rolling window',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            range.label,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      DropdownButton<AnalyticsRange>(
                        value: _selectedRange,
                        items: AnalyticsRange.values
                            .map(
                              (range) => DropdownMenuItem(
                                value: range,
                                child: Text(range.label),
                              ),
                            )
                            .toList(),
                        onChanged: (selection) {
                          if (selection == null) return;
                          setState(() {
                            _selectedRange = selection;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        title: 'Attendance rate',
                        value: '$attendanceRate%',
                        subtitle: '${breakdown.total} check-ins',
                        background: Colors.green.shade50,
                        accent: Colors.green.shade700,
                      ),
                      _StatCard(
                        title: 'Absences',
                        value: '${breakdown.absent}',
                        subtitle: maxAbsenceStreak == 0
                            ? 'No recent absences'
                            : 'Longest streak: $maxAbsenceStreak',
                        background: Colors.red.shade50,
                        accent: Colors.red.shade700,
                      ),
                      _StatCard(
                        title: 'Late arrivals',
                        value: '${breakdown.partial}',
                        subtitle: 'Latest trend $latestTrend%',
                        background: Colors.orange.shade50,
                        accent: Colors.orange.shade800,
                      ),
                      _StatCard(
                        title: 'Watchlist',
                        value: '${analytics.watchlist.length}',
                        subtitle: analytics.watchlist.isEmpty
                            ? 'All clear'
                            : 'Needs follow-up',
                        background: Colors.blue.shade50,
                        accent: Colors.blue.shade800,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Wellness watchlist',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Icon(Icons.favorite_outline,
                                  color: Theme.of(context).colorScheme.primary),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (analytics.watchlist.isEmpty)
                            Text(
                              'No repeated misses detected in this window.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            )
                          else
                            ...analytics.watchlist.map(
                              (flag) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: flag.isFamily
                                      ? Colors.indigo.shade50
                                      : Colors.red.shade50,
                                  child: Icon(
                                    flag.isFamily
                                        ? Icons.groups_outlined
                                        : Icons.warning_amber_rounded,
                                    color: flag.isFamily
                                        ? Colors.indigo.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                                title: Text(flag.subject),
                                subtitle: Text(flag.reason),
                                trailing: TextButton(
                                  onPressed: () {},
                                  child: const Text('Follow up'),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Drill-down insights',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                range.label,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 90,
                            child: _SparklineChart(data: analytics.trend),
                          ),
                          const SizedBox(height: 12),
                          _StatusBarChart(breakdown: breakdown),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Quick actions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _ActionChipButton(
                        icon: Icons.fact_check_outlined,
                        label: 'Take attendance',
                        onPressed: () => _startAttendanceFlow(context),
                      ),
                      _ActionChipButton(
                        icon: Icons.person_add_alt_1,
                        label: 'Add attendee',
                        onPressed: () => _startAttendanceFlow(context),
                      ),
                      _ActionChipButton(
                        icon: Icons.bar_chart_outlined,
                        label: 'View stats',
                        onPressed: () => _startAttendanceFlow(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent sessions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _homeDataFuture = _loadHomeData();
                          });
                        },
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (homeData.sessions.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('No sessions saved yet'),
                        subtitle: Text(
                          'Start taking attendance to build history.',
                        ),
                      ),
                    ),
                  ...homeData.sessions.take(5).map((session) {
                    final attended = session.records
                        .where(
                          (record) => record.status == AttendanceStatus.present,
                        )
                        .length;
                    final expected = session.records.length;
                    final percent = expected == 0
                        ? 0
                        : (attended / expected * 100).round();
                    final dateLabel = session.sessionDate
                        .toLocal()
                        .toString()
                        .split(' ')
                        .first;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: Text(
                            '${percent}%',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        title: Text(session.title),
                        subtitle: Text(
                          '$dateLabel · $attended of $expected present',
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 18,
                          ),
                          onPressed: () => _openSession(session),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color background;
  final Color accent;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.background,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: Card(
        color: background,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: accent),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _SparklineChart extends StatelessWidget {
  const _SparklineChart({required this.data});

  final List<double> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No trend data yet',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return CustomPaint(
      painter: _SparklinePainter(data),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            'Trend',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.data);

  final List<double> data;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.indigo.shade400
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.indigo.shade100
      ..style = PaintingStyle.fill;

    final maxValue = data.reduce(math.max).clamp(1, 100);
    final minValue = data.reduce(math.min);
    final range = (maxValue - minValue).abs();
    final horizontalStep = data.length == 1 ? 0.0 : size.width / (data.length - 1);

    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final normalized = range == 0 ? 0.5 : (data[i] - minValue) / range;
      final y = size.height - (normalized * size.height);
      points.add(Offset(i * horizontalStep, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatusBarChart extends StatelessWidget {
  const _StatusBarChart({required this.breakdown});

  final AttendanceBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final maxValue = [breakdown.present, breakdown.partial, breakdown.absent]
        .fold<int>(1, (value, element) => math.max(value, element));

    Widget buildBar(String label, int count, Color color) {
      final height = count == 0 ? 6.0 : (count / maxValue) * 70 + 6;
      return Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 20,
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text('$count', style: Theme.of(context).textTheme.labelMedium),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status breakdown',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            buildBar('Present', breakdown.present, Colors.green.shade400),
            buildBar('Late', breakdown.partial, Colors.orange.shade400),
            buildBar('Absent', breakdown.absent, Colors.red.shade400),
          ],
        ),
      ],
    );
  }
}

class _HomeData {
  const _HomeData({
    this.sessions = const [],
    this.families = const [],
  });

  final List<Session> sessions;
  final List<Family> families;
}
