import 'package:flutter/material.dart';

import 'data/session.dart';
import 'data/session_repository.dart';
import 'features/attendance/data/attendance_repository.dart';
import 'features/attendance/models/attendance_status.dart';
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
  late Future<List<Session>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = widget.sessionRepository.loadSessions();
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
      _sessionsFuture = widget.sessionRepository.loadSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Session>>(
      future: _sessionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final sessions = snapshot.data ?? [];

        final present = sessions
            .expand((session) => session.records)
            .where((record) => record.status == AttendanceStatus.present)
            .length;
        final total = sessions.expand((session) => session.records).length;
        final partial = sessions
            .expand((session) => session.records)
            .where((record) => record.status == AttendanceStatus.partial)
            .length;
        final absent = total - present - partial;
        final attendanceRate = total == 0 ? 0 : (present / total * 100).round();

        return Scaffold(
          appBar: AppBar(title: const Text('Attendance Tracker')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _sessionsFuture = widget.sessionRepository.loadSessions();
                });
                await _sessionsFuture;
              },
              child: ListView(
                children: [
                  Text(
                    "Today's overview",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        title: 'Present',
                        value: '$present',
                        subtitle: '$attendanceRate% checked in',
                        background: Colors.green.shade50,
                        accent: Colors.green.shade700,
                      ),
                      _StatCard(
                        title: 'Absent',
                        value: '$absent',
                        subtitle: 'Out today',
                        background: Colors.red.shade50,
                        accent: Colors.red.shade700,
                      ),
                      _StatCard(
                        title: 'Late arrivals',
                        value: '$partial',
                        subtitle: 'Follow up needed',
                        background: Colors.orange.shade50,
                        accent: Colors.orange.shade800,
                      ),
                    ],
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
                            _sessionsFuture = widget.sessionRepository
                                .loadSessions(includeDeleted: true);
                          });
                        },
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (sessions.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('No sessions saved yet'),
                        subtitle: Text(
                          'Start taking attendance to build history.',
                        ),
                      ),
                    ),
                  ...sessions.take(5).map((session) {
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
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.insights_outlined),
                      title: const Text('Engagement trend'),
                      subtitle: Text(
                        total == 0
                            ? 'No attendance recorded yet.'
                            : 'Attendance is tracking at $attendanceRate% this week.',
                      ),
                      trailing: FilledButton(
                        onPressed: () => _startAttendanceFlow(context),
                        child: const Text('See details'),
                      ),
                    ),
                  ),
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
