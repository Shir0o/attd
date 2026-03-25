import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/drive_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class CloudBackupPage extends StatefulWidget {
  const CloudBackupPage({
    super.key,
    required this.driveService,
    this.disableAnimations = false,
  });

  final DriveService driveService;
  final bool disableAnimations;

  @override
  State<CloudBackupPage> createState() => _CloudBackupPageState();
}

class _CloudBackupPageState extends State<CloudBackupPage> {
  late Future<List<drive.File>> _backupsFuture;
  bool _isInitialLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isInitialLoading = true);
    }

    final startTime = DateTime.now();

    try {
      _backupsFuture = widget.driveService.listCloudBackups();
      await _backupsFuture;
    } catch (e) {
      // Error handled by FutureBuilder
    }

    final elapsed = DateTime.now().difference(startTime);
    final minDuration = isRefresh
        ? const Duration(milliseconds: 800)
        : const Duration(milliseconds: 1200);

    final remaining = minDuration - elapsed;
    if (remaining > Duration.zero && !widget.disableAnimations) {
      await Future.delayed(remaining);
    }

    if (mounted) {
      setState(() {
        _isInitialLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _restore(drive.File backup) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHigh,
        title: Text(
          'Restore from Cloud',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to restore the backup from ${DateFormat('MMM d, HH:mm').format(backup.createdTime!)}?\n\nThis will merge the backup data with your current data on this device.',
          style: theme.textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      try {
        final backupDate =
            DateFormat('MMM d, HH:mm').format(backup.createdTime!);
        await widget.driveService.restoreFromBackup(
          backup.id!,
          backupDateLabel: backupDate,
        );
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Restoration successful'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (mounted) Navigator.pop(context);
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Restoration failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Cloud Version History',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _isInitialLoading
          ? _buildSkeleton(context)
          : FutureBuilder<List<drive.File>>(
              future: _backupsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !_isRefreshing) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load history',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => _loadInitialData(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final backups = snapshot.data ?? [];

                if (backups.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.cloud_off_outlined,
                              size: 64,
                              color: colorScheme.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'No Cloud Backups',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Previous snapshots of your data will appear here once you enable Cloud Sync.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: backups.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final backup = backups[index];
                    final dateStr = DateFormat('EEEE, MMM d').format(
                      backup.createdTime!,
                    );
                    final yearStr = DateFormat('yyyy').format(
                      backup.createdTime!,
                    );
                    final timeStr = DateFormat('h:mm a').format(
                      backup.createdTime!,
                    );

                    return Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.backup_rounded,
                                color: colorScheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$dateStr, $yearStr',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Saved at $timeStr',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            FilledButton(
                              onPressed: () => _restore(backup),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                shape: const StadiumBorder(),
                              ),
                              child: const Text('Restore'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          height: 88,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              _ShimmerBox(
                width: 52,
                height: 52,
                borderRadius: BorderRadius.circular(18),
                disableAnimations: widget.disableAnimations,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ShimmerBox(
                      width: 180,
                      height: 18,
                      borderRadius: BorderRadius.circular(4),
                      disableAnimations: widget.disableAnimations,
                    ),
                    const SizedBox(height: 10),
                    _ShimmerBox(
                      width: 100,
                      height: 14,
                      borderRadius: BorderRadius.circular(4),
                      disableAnimations: widget.disableAnimations,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              _ShimmerBox(
                width: 88,
                height: 40,
                borderRadius: BorderRadius.circular(100),
                disableAnimations: widget.disableAnimations,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius,
    this.disableAnimations = false,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final bool disableAnimations;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    if (!widget.disableAnimations) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseColor = colorScheme.surfaceContainerHigh.withValues(
      alpha: 0.3,
    );
    final highlightColor = colorScheme.surfaceContainerHigh.withValues(
      alpha: 0.1,
    );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, -1),
              end: Alignment(_animation.value + 1, 1),
              colors: [baseColor, highlightColor, baseColor],
            ),
          ),
        );
      },
    );
  }
}
