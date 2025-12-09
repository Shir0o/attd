import 'package:flutter/material.dart';

void main() {
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AttendanceHomePage(),
    );
  }
}

class AttendanceHomePage extends StatelessWidget {
  const AttendanceHomePage({super.key});

  void _showPlaceholder(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    const present = 24;
    const total = 26;
    const late = 1;
    const records = [
      ('Design Standup', '8:30 AM', 12, 14),
      ('Client Review', '10:00 AM', 9, 10),
      ('Engineering Sync', '2:00 PM', 18, 19),
    ];

    final absent = total - present;
    final attendanceRate = (present / total * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Tracker'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Today's overview",
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
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
                    value: '$late',
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
                    onPressed: () =>
                        _showPlaceholder(context, 'Taking attendance'),
                  ),
                  _ActionChipButton(
                    icon: Icons.person_add_alt_1,
                    label: 'Add attendee',
                    onPressed: () => _showPlaceholder(context, 'Adding attendee'),
                  ),
                  _ActionChipButton(
                    icon: Icons.bar_chart_outlined,
                    label: 'View stats',
                    onPressed: () => _showPlaceholder(context, 'Viewing stats'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Recent sessions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...records.map((record) {
                final title = record.$1;
                final time = record.$2;
                final attended = record.$3;
                final expected = record.$4;
                final percent = (attended / expected * 100).round();

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        '${percent}%',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    title: Text(title),
                    subtitle: Text('$time · $attended of $expected present'),
                    trailing: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                      onPressed: () => _showPlaceholder(context, 'Viewing $title'),
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
                    'Attendance is tracking at $attendanceRate% this week.',
                  ),
                  trailing: FilledButton(
                    onPressed: () =>
                        _showPlaceholder(context, 'Opening weekly trend'),
                    child: const Text('See details'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: accent),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: accent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: accent),
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
