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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isInitialLoading = true);
    final startTime = DateTime.now();

    _backupsFuture = widget.driveService.listCloudBackups();
    await _backupsFuture;

    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(milliseconds: 1200) - elapsed;
    if (remaining > Duration.zero && !widget.disableAnimations) {
      await Future.delayed(remaining);
    }

    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _restore(drive.File backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from Cloud'),
        content: Text(
          'Are you sure you want to restore the backup from ${DateFormat('MMM d, HH:mm').format(backup.createdTime!)}?\n\nThis will replace all current data on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
          const SnackBar(content: Text('Restoration successful')),
        );
        if (mounted) Navigator.pop(context);
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Restoration failed: $e')),
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
        title: const Text(
          'Cloud Version History',
          style: TextStyle(fontWeight: FontWeight.normal),
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final backups = snapshot.data ?? [];

                if (backups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('No cloud version history found'),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: backups.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final backup = backups[index];
                    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(
                      backup.createdTime!,
                    );
                    final timeStr = DateFormat('hh:mm a').format(
                      backup.createdTime!,
                    );
                    final size = (int.parse(backup.size ?? '0') / 1024)
                        .toStringAsFixed(1);

                    return Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: Text(
                          dateStr,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Snapshot at $timeStr • $size KB'),
                        trailing: TextButton(
                          onPressed: () => _restore(backup),
                          child: const Text('Restore'),
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
      itemCount: 6,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          height: 88,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
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
                    const SizedBox(height: 8),
                    _ShimmerBox(
                      width: 140,
                      height: 14,
                      borderRadius: BorderRadius.circular(4),
                      disableAnimations: widget.disableAnimations,
                    ),
                  ],
                ),
              ),
              _ShimmerBox(
                width: 60,
                height: 32,
                borderRadius: BorderRadius.circular(8),
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
