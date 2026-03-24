import 'package:flutter/material.dart';

class MockAttendanceSwipe extends StatelessWidget {
  const MockAttendanceSwipe({super.key});

  @override
  Widget build(BuildContext context) {
    return _MockContainer(
      child: Column(
        children: [
          _MockHeader(title: 'Quick Mark'),
          const SizedBox(height: 16),
          _MockListItem(
            label: 'John Doe',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chevron_left, color: Colors.red),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('PRESENT', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const Icon(Icons.chevron_right, color: Colors.green),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _MockListItem(
            label: 'Jane Smith',
            trailing: const Icon(Icons.swipe, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          _MockListItem(
            label: 'Robert Johnson',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chevron_left, color: Colors.red),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('ABSENT', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const Icon(Icons.chevron_right, color: Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MockSessionHistory extends StatelessWidget {
  const MockSessionHistory({super.key});

  @override
  Widget build(BuildContext context) {
    return _MockContainer(
      child: Column(
        children: [
          _MockHeader(title: 'Recent Sessions'),
          const SizedBox(height: 16),
          _MockHistoryItem(title: 'Weekly Meetup', date: 'March 20, 2026', count: '18/20'),
          _MockHistoryItem(title: 'Special Event', date: 'March 15, 2026', count: '45/50'),
          _MockHistoryItem(title: 'Weekly Meetup', date: 'March 13, 2026', count: '15/20'),
        ],
      ),
    );
  }
}

class MockManageMembers extends StatelessWidget {
  const MockManageMembers({super.key});

  @override
  Widget build(BuildContext context) {
    return _MockContainer(
      child: Column(
        children: [
          _MockHeader(title: 'Families & Members'),
          const SizedBox(height: 16),
          _MockFamilyItem(name: 'Doe Family', count: 4),
          _MockFamilyItem(name: 'Smith Family', count: 2),
          _MockFamilyItem(name: 'Johnson Family', count: 3),
        ],
      ),
    );
  }
}

class MockCloudBackup extends StatelessWidget {
  const MockCloudBackup({super.key});

  @override
  Widget build(BuildContext context) {
    return _MockContainer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_done_outlined, size: 64, color: Colors.blue),
          const SizedBox(height: 24),
          const Text('Google Drive Sync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Status: Synced', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: 1.0,
            backgroundColor: Colors.blue.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          const Text('Last synced: Just now', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

class MockManageBackup extends StatelessWidget {
  const MockManageBackup({super.key});

  @override
  Widget build(BuildContext context) {
    return _MockContainer(
      child: Column(
        children: [
          _MockHeader(title: 'Data & Backups'),
          const SizedBox(height: 16),
          _MockBackupAction(icon: Icons.download_rounded, label: 'Export to CSV', color: Colors.green),
          _MockBackupAction(icon: Icons.backup_rounded, label: 'Create Local Backup', color: Colors.blue),
          _MockBackupAction(icon: Icons.restore_rounded, label: 'Restore from File', color: Colors.orange),
        ],
      ),
    );
  }
}

class _MockContainer extends StatelessWidget {
  const _MockContainer({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MockHeader extends StatelessWidget {
  const _MockHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
      ],
    );
  }
}

class _MockListItem extends StatelessWidget {
  const _MockListItem({required this.label, this.trailing});
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _MockHistoryItem extends StatelessWidget {
  const _MockHistoryItem({required this.title, required this.date, required this.count});
  final String title;
  final String date;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.history_rounded, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text(count, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        ],
      ),
    );
  }
}

class _MockFamilyItem extends StatelessWidget {
  const _MockFamilyItem({required this.name, required this.count});
  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          const CircleAvatar(radius: 18, child: Icon(Icons.group_rounded, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _MockBackupAction extends StatelessWidget {
  const _MockBackupAction({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
    );
  }
}
