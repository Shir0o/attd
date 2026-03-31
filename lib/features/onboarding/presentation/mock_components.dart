import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';

class MockAttendanceSwipe extends StatelessWidget {
  const MockAttendanceSwipe({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                Icon(Icons.chevron_left, color: colorScheme.error),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text('PRESENT', style: TextStyle(color: AppColors.tertiary, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                Icon(Icons.chevron_right, color: AppColors.tertiary),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _MockListItem(
            label: 'Jane Smith',
            trailing: Icon(Icons.swipe, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          _MockListItem(
            label: 'Robert Johnson',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left, color: colorScheme.error),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text('ABSENT', style: TextStyle(color: colorScheme.error, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                Icon(Icons.chevron_right, color: AppColors.tertiary),
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
    final colorScheme = Theme.of(context).colorScheme;
    return _MockContainer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_done_outlined, size: 64, color: colorScheme.primary),
          const SizedBox(height: 24),
          Text('Google Drive Sync', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Status: Synced', style: TextStyle(color: AppColors.tertiary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: 1.0,
            backgroundColor: colorScheme.primary.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            borderRadius: BorderRadius.circular(24),
          ),
          const SizedBox(height: 12),
          Text('Last synced: Just now', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class MockManageBackup extends StatelessWidget {
  const MockManageBackup({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _MockContainer(
      child: Column(
        children: [
          _MockHeader(title: 'Data & Backups'),
          const SizedBox(height: 16),
          _MockBackupAction(icon: Icons.download_rounded, label: 'Export to CSV', color: AppColors.tertiary),
          _MockBackupAction(icon: Icons.backup_rounded, label: 'Create Local Backup', color: colorScheme.primary),
          _MockBackupAction(icon: Icons.restore_rounded, label: 'Restore from File', color: AppColors.secondary),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDim.withOpacity(0.04),
            blurRadius: 32,
            offset: Offset.zero,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Icon(Icons.more_vert_rounded, size: 20, color: colorScheme.onSurfaceVariant),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
          ?trailing,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.history_rounded, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(date, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(count, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colorScheme.primary)),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          const CircleAvatar(radius: 18, child: Icon(Icons.group_rounded, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text('$count', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
          const Spacer(),
          Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
        ],
      ),
    );
  }
}
