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
          _MockHeader(title: 'Marking Present'),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 3 / 2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background card
                Transform.translate(
                  offset: const Offset(0, 8),
                  child: Transform.scale(
                    scale: 0.9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                // Main card being swiped
                Transform.translate(
                  offset: const Offset(40, -10),
                  child: Transform.rotate(
                    angle: 0.1,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text('JD', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 20)),
                          ),
                          const SizedBox(height: 12),
                          Text('John Doe', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                // Present indicator overlay
                Positioned(
                  right: 20,
                  top: 20,
                  child: Transform.rotate(
                    angle: 0.2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.tertiary, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PRESENT',
                        style: TextStyle(
                          color: AppColors.tertiary,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MockRoundButton(icon: Icons.undo, color: colorScheme.onSurfaceVariant.withOpacity(0.5), size: 40),
              const SizedBox(width: 16),
              _MockRoundButton(icon: Icons.close, color: colorScheme.error, size: 48),
              const SizedBox(width: 16),
              _MockRoundButton(icon: Icons.check, color: colorScheme.onPrimary, backgroundColor: colorScheme.primary, size: 48),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockRoundButton extends StatelessWidget {
  const _MockRoundButton({required this.icon, required this.color, this.backgroundColor, required this.size});
  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size * 0.6),
    );
  }
}

class MockSessionHistory extends StatelessWidget {
  const MockSessionHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _MockContainer(
      child: Column(
        children: [
          _MockHeader(title: 'History'),
          const SizedBox(height: 16),
          _MockHistoryItem(
            title: 'Sunday Service',
            date: 'Today, 10:00 AM',
            count: '42',
            color: colorScheme.primary,
          ),
          _MockHistoryItem(
            title: 'Midweek Prayer',
            date: 'Wednesday, 7:00 PM',
            count: '28',
            color: AppColors.tertiary,
          ),
          _MockHistoryItem(
            title: 'Youth Night',
            date: 'Last Friday, 6:30 PM',
            count: '35',
            color: AppColors.secondary,
          ),
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
          _MockHeader(title: 'People'),
          const SizedBox(height: 16),
          _MockFamilyItem(name: 'The Andersons', count: 4, initials: 'A'),
          _MockFamilyItem(name: 'The Bakers', count: 2, initials: 'B'),
          _MockFamilyItem(name: 'The Campbells', count: 5, initials: 'C'),
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

class _MockHistoryItem extends StatelessWidget {
  const _MockHistoryItem({
    required this.title,
    required this.date,
    required this.count,
    this.color,
  });
  final String title;
  final String date;
  final String count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final itemColor = color ?? colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: itemColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.history_rounded, color: itemColor, size: 20),
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
          Text(count, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: itemColor)),
        ],
      ),
    );
  }
}

class _MockFamilyItem extends StatelessWidget {
  const _MockFamilyItem({
    required this.name,
    required this.count,
    required this.initials,
  });
  final String name;
  final int count;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.surfaceContainerHigh,
            child: Text(
              initials,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
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
