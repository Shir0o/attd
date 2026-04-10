import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';

class MockAttendanceSwipe extends StatelessWidget {
  const MockAttendanceSwipe({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: 10),
        SizedBox(
          height: 340,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Left swipe card (ABSENT) - positioned behind
              Transform.translate(
                offset: const Offset(-50, 40),
                child: Transform.rotate(
                  angle: -0.15,
                  child: const _EnlargedCard(
                    initials: 'JS',
                    name: 'Jane Smith',
                    label: 'ABSENT',
                    labelColor: Colors.red,
                    isLeft: true,
                  ),
                ),
              ),
              // Right swipe card (PRESENT) - positioned front
              Transform.translate(
                offset: const Offset(50, -20),
                child: Transform.rotate(
                  angle: 0.15,
                  child: _EnlargedCard(
                    initials: 'JD',
                    name: 'John Doe',
                    label: 'PRESENT',
                    labelColor: AppColors.tertiary,
                    isLeft: false,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MockRoundButton(
              icon: Icons.undo,
              color: colorScheme.onSurfaceVariant,
              backgroundColor: colorScheme.surfaceContainerHigh,
              size: 80,
            ),
            const SizedBox(width: 24),
            _MockRoundButton(
              icon: Icons.close,
              color: colorScheme.error,
              backgroundColor: colorScheme.surfaceContainerHigh,
              size: 80,
              elevation: 1,
            ),
            const SizedBox(width: 24),
            _MockRoundButton(
              icon: Icons.check,
              color: colorScheme.onPrimary,
              backgroundColor: colorScheme.primary,
              size: 80,
              elevation: 3,
            ),
          ],
        ),
      ],
    );
  }
}

class _EnlargedCard extends StatelessWidget {
  const _EnlargedCard({
    required this.initials,
    required this.name,
    required this.label,
    required this.labelColor,
    required this.isLeft,
  });

  final String initials;
  final String name;
  final String label;
  final Color labelColor;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 200,
      height: 240,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -12,
            left: isLeft ? -12 : null,
            right: isLeft ? null : -12,
            child: Transform.rotate(
              angle: isLeft ? -0.2 : 0.2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border.all(color: labelColor, width: 3),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockRoundButton extends StatelessWidget {
  const _MockRoundButton({
    required this.icon,
    required this.color,
    this.backgroundColor,
    required this.size,
    this.elevation = 0,
  });
  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final double size;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: BoxShape.circle,
        boxShadow: elevation > 0 ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: elevation * 2,
            offset: Offset(0, elevation),
          )
        ] : null,
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class MockSessionHistory extends StatelessWidget {
  const MockSessionHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _MockSessionCard(
          title: 'Sunday Service',
          date: 'Mar 29, 2026',
          dayTime: 'Sunday • 10:00 AM',
          present: 42,
          absent: 3,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _MockSessionCard(
          title: 'Midweek Prayer',
          date: 'Mar 25, 2026',
          dayTime: 'Wednesday • 7:00 PM',
          present: 28,
          absent: 14,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _MockSessionCard(
          title: 'Youth Night',
          date: 'Mar 20, 2026',
          dayTime: 'Friday • 6:30 PM',
          present: 35,
          absent: 5,
          colorScheme: colorScheme,
        ),
      ],
    );
  }
}

class _MockSessionCard extends StatelessWidget {
  const _MockSessionCard({
    required this.title,
    required this.date,
    required this.dayTime,
    required this.present,
    required this.absent,
    required this.colorScheme,
  });

  final String title;
  final String date;
  final String dayTime;
  final int present;
  final int absent;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    dayTime,
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MockStatusBadge(
                icon: Icons.check_circle,
                color: colorScheme.primary,
                label: '$present Present',
                onSurface: colorScheme.onSurface,
              ),
              Container(
                height: 16,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: colorScheme.outlineVariant,
              ),
              _MockStatusBadge(
                icon: Icons.cancel,
                color: colorScheme.error,
                label: '$absent Absent',
                onSurface: colorScheme.onSurface,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockStatusBadge extends StatelessWidget {
  const _MockStatusBadge({
    required this.icon,
    required this.color,
    required this.label,
    required this.onSurface,
  });

  final IconData icon;
  final Color color;
  final String label;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: onSurface,
          ),
        ),
      ],
    );
  }
}

class MockManageMembers extends StatelessWidget {
  const MockManageMembers({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.surfaceContainerHigh),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: colorScheme.onSurfaceVariant, size: 20),
                        const SizedBox(width: 8),
                        Text('Find or add member', 
                          style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _MockRoundButton(
                  icon: Icons.add,
                  color: colorScheme.onPrimary,
                  backgroundColor: colorScheme.primary,
                  size: 48,
                  elevation: 1,
                ),
              ],
            ),
          ),
          _MockMemberTile(name: 'Jane Smith', initials: 'JS', colorScheme: colorScheme),
          _MockMemberTile(name: 'John Doe', initials: 'JD', colorScheme: colorScheme),
          _MockMemberTile(name: 'Alice Johnson', initials: 'AJ', colorScheme: colorScheme),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MockMemberTile extends StatelessWidget {
  const _MockMemberTile({
    required this.name,
    required this.initials,
    required this.colorScheme,
  });

  final String name;
  final String initials;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.primary.withOpacity(0.1),
        child: Text(
          initials,
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_outlined, color: colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Icon(Icons.delete_outline, color: colorScheme.onSurfaceVariant, size: 20),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_sync,
                  color: colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Google Drive Sync',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'user@example.com',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: const Text('Sign Out', 
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sync, color: colorScheme.onPrimary, size: 18),
                      const SizedBox(width: 8),
                      Text('Sync Now', 
                        style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _MockSettingsTile(
            icon: Icons.people_outline,
            title: 'Manage Members',
            subtitle: 'Add, edit, or remove members',
            colorScheme: colorScheme,
          ),
          _MockSettingsTile(
            icon: Icons.cleaning_services,
            title: 'Manage Backup Data',
            subtitle: 'Clean up hidden or orphaned records',
            colorScheme: colorScheme,
          ),
          _MockSettingsTile(
            icon: Icons.save,
            title: 'Backup to Local Storage',
            subtitle: 'Create a full backup on this device',
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }
}

class _MockSettingsTile extends StatelessWidget {
  const _MockSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colorScheme,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: colorScheme.onPrimaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: colorScheme.onSurfaceVariant,
            size: 24,
          ),
        ],
      ),
    );
  }
}
