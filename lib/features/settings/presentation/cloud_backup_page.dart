import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../../../core/design/app_radii.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/fluid_loading_border.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../data/drive_service.dart';

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
  bool _isOperating = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _performOperation(Future<void> Function() action) async {
    setState(() => _isOperating = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _isOperating = false);
      }
    }
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
          'Are you sure you want to restore the backup from ${_formatVersionDate(backup.createdTime!)}?\n\nThis will merge the backup data with your current data on this device.',
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
      await _performOperation(() async {
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
      });
    }
  }

  Future<void> _overwriteLocal() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHigh,
        title: Text(
          'Overwrite Local Data?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will replace all data on this device with the data from your Google Drive.\n\nThis can\'t be undone.',
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
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      await _performOperation(() async {
        try {
          await widget.driveService.overwriteLocalWithCloud();
          await _loadInitialData(isRefresh: true);
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Local data overwritten'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (e) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
  }

  Future<void> _overwriteCloud() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surfaceContainerHigh,
        title: Text(
          'Overwrite Cloud Data?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will replace all data on your Google Drive with the data currently on this device.\n\nThis can\'t be undone.',
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
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      await _performOperation(() async {
        try {
          await widget.driveService.overwriteCloudWithLocal();
          await _loadInitialData(isRefresh: true);
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Cloud data overwritten'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (e) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
  }

  String _formatVersionDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeStr = DateFormat('HH:mm').format(dateTime);

    if (date == today) {
      return 'Today · $timeStr';
    } else if (date == yesterday) {
      return 'Yesterday · $timeStr';
    } else {
      final monthDayStr = DateFormat('MMM d').format(dateTime);
      return '$monthDayStr · $timeStr';
    }
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.isNegative) {
      return 'just now';
    }
    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        leading: const BackButton(),
        title: const ConvEyebrow('Version history'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: FluidLoadingBorder(
        isLoading: _isOperating,
        child: _isInitialLoading
            ? _buildSkeleton(context)
            : FutureBuilder<List<drive.File>>(
                future: _backupsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !_isRefreshing) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: c.absent),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load history',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: c.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: c.ink3,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: () => _loadInitialData(isRefresh: true),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try Again'),
                              style: FilledButton.styleFrom(
                                backgroundColor: c.primary,
                                foregroundColor: c.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final backups = snapshot.data ?? [];
                  final lastSync = widget.driveService.lastSyncTime;
                  final syncSubText = lastSync != null
                      ? '${backups.length} snapshots kept · last ${_formatRelativeTime(lastSync)}'
                      : '${backups.length} snapshots kept · last sync: never';

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
                    children: [
                      Text(
                        'Version\nhistory',
                        style: AppTypography.fraunces(
                          fontSize: 32,
                          color: c.ink,
                          height: 1.0,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // sync state card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: AppRadii.cardR,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: c.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.cloud_outlined,
                                  color: c.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Google Drive · in sync',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: c.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    syncSubText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c.ink3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF3CD070),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Force section
                      Text(
                        'If they don\'t match'.toUpperCase(),
                        style: AppTypography.eyebrow(color: c.ink3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Force one side to win. This replaces the whole copy on the other side — it can\'t be undone.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.ink3,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _OverwriteButton(
                            isCloud: false,
                            title: 'Overwrite local',
                            subtitle: 'Pull the cloud copy down to this device',
                            onTap: _isOperating ? null : _overwriteLocal,
                          ),
                          const SizedBox(width: 10),
                          _OverwriteButton(
                            isCloud: true,
                            title: 'Overwrite cloud',
                            subtitle: 'Push this device up, replacing the cloud',
                            onTap: _isOperating ? null : _overwriteCloud,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      // Snapshots timeline section
                      Text(
                        'Snapshots'.toUpperCase(),
                        style: AppTypography.eyebrow(color: c.ink3),
                      ),
                      const SizedBox(height: 16),
                      if (backups.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history_toggle_off_rounded,
                                size: 36,
                                color: c.ink4,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No Cloud Backups',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: c.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Snapshots will appear here once created.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.ink3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        ...List.generate(backups.length, (index) {
                          final backup = backups[index];
                          final isCurrent = index == 0 &&
                              widget.driveService.lastSyncTime != null;
                          return _VersionRow(
                            backup: backup,
                            isCurrent: isCurrent,
                            isLast: index == backups.length - 1,
                            onRestore: _restore,
                            formatVersionDate: _formatVersionDate,
                            formatRelativeTime: _formatRelativeTime,
                          );
                        }),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Older snapshots are thinned automatically.\nDrive keeps the last 30 days.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: c.ink4,
                          height: 1.5,
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final c = context.conv;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Title skeleton
        const SizedBox(height: 10),
        AppShimmer(
          width: 140,
          height: 32,
          borderRadius: BorderRadius.circular(4),
          disableAnimations: widget.disableAnimations,
        ),
        const SizedBox(height: 8),
        AppShimmer(
          width: 100,
          height: 32,
          borderRadius: BorderRadius.circular(4),
          disableAnimations: widget.disableAnimations,
        ),
        const SizedBox(height: 18),
        // Sync card skeleton
        Container(
          height: 76,
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: AppRadii.cardR,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AppShimmer(
                width: 44,
                height: 44,
                borderRadius: BorderRadius.circular(14),
                disableAnimations: widget.disableAnimations,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppShimmer(
                      width: 160,
                      height: 16,
                      borderRadius: BorderRadius.circular(4),
                      disableAnimations: widget.disableAnimations,
                    ),
                    const SizedBox(height: 6),
                    AppShimmer(
                      width: 200,
                      height: 12,
                      borderRadius: BorderRadius.circular(4),
                      disableAnimations: widget.disableAnimations,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // If they don't match section label
        AppShimmer(
          width: 120,
          height: 12,
          borderRadius: BorderRadius.circular(2),
          disableAnimations: widget.disableAnimations,
        ),
        const SizedBox(height: 12),
        // Force buttons skeleton
        Row(
          children: [
            Expanded(
              child: Container(
                height: 124,
                decoration: BoxDecoration(
                  color: c.cardSoft,
                  border: Border.all(color: c.hair, width: 1.5),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppShimmer(
                      width: 40,
                      height: 40,
                      borderRadius: BorderRadius.circular(12),
                      disableAnimations: widget.disableAnimations,
                    ),
                    const SizedBox(height: 10),
                    AppShimmer(
                      width: 80,
                      height: 14,
                      borderRadius: BorderRadius.circular(4),
                      disableAnimations: widget.disableAnimations,
                    ),
                    const SizedBox(height: 6),
                    AppShimmer(
                      width: 100,
                      height: 10,
                      borderRadius: BorderRadius.circular(4),
                      disableAnimations: widget.disableAnimations,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 124,
                decoration: BoxDecoration(
                  color: c.cardSoft,
                  border: Border.all(color: c.hair, width: 1.5),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppShimmer(
                      width: 40,
                      height: 40,
                      borderRadius: BorderRadius.circular(12),
                      disableAnimations: widget.disableAnimations,
                    ),
                    const SizedBox(height: 10),
                    AppShimmer(
                      width: 80,
                      height: 14,
                      borderRadius: BorderRadius.circular(4),
                      disableAnimations: widget.disableAnimations,
                    ),
                    const SizedBox(height: 6),
                    AppShimmer(
                      width: 100,
                      height: 10,
                      borderRadius: BorderRadius.circular(4),
                      disableAnimations: widget.disableAnimations,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        // Snapshots label skeleton
        AppShimmer(
          width: 80,
          height: 12,
          borderRadius: BorderRadius.circular(2),
          disableAnimations: widget.disableAnimations,
        ),
        const SizedBox(height: 16),
        // Timeline rows skeleton
        ...List.generate(3, (index) {
          final isLast = index == 2;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 14,
                  child: Column(
                    children: [
                      const SizedBox(height: 5),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.card,
                          border: Border.all(color: c.hair, width: 2),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.only(top: 2),
                            color: c.hair,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppShimmer(
                              width: 120,
                              height: 14,
                              borderRadius: BorderRadius.circular(4),
                              disableAnimations: widget.disableAnimations,
                            ),
                            const Spacer(),
                            AppShimmer(
                              width: 40,
                              height: 12,
                              borderRadius: BorderRadius.circular(4),
                              disableAnimations: widget.disableAnimations,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        AppShimmer(
                          width: 150,
                          height: 12,
                          borderRadius: BorderRadius.circular(4),
                          disableAnimations: widget.disableAnimations,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            AppShimmer(
                              width: 80,
                              height: 22,
                              borderRadius: BorderRadius.circular(999),
                              disableAnimations: widget.disableAnimations,
                            ),
                            const Spacer(),
                            AppShimmer(
                              width: 70,
                              height: 28,
                              borderRadius: BorderRadius.circular(999),
                              disableAnimations: widget.disableAnimations,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _OverwriteButton extends StatelessWidget {
  const _OverwriteButton({
    required this.isCloud,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final bool isCloud;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final color = isCloud ? c.absent : c.primary;
    final icon =
        isCloud ? Icons.cloud_upload_outlined : Icons.cloud_download_outlined;

    return Expanded(
      child: Material(
        color: c.cardSoft,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: c.hair, width: 1.5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: AppTypography.geist(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.geist(
                    fontSize: 11.5,
                    color: c.ink3,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.backup,
    required this.isCurrent,
    required this.isLast,
    required this.onRestore,
    required this.formatVersionDate,
    required this.formatRelativeTime,
  });

  final drive.File backup;
  final bool isCurrent;
  final bool isLast;
  final ValueChanged<drive.File> onRestore;
  final String Function(DateTime) formatVersionDate;
  final String Function(DateTime) formatRelativeTime;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;

    Map<String, dynamic> metadata = {};
    try {
      if (backup.description != null) {
        metadata = jsonDecode(backup.description!) as Map<String, dynamic>;
      }
    } catch (_) {}

    final user = metadata['user'] ?? 'System';
    final deviceLabel =
        user == 'System' ? 'System' : (isCurrent ? 'This device' : user);

    final int? bytes =
        backup.size != null ? int.tryParse(backup.size!) : null;
    final sizeLabel = _formatSize(bytes);

    final tags = metadata['tags'] as List?;
    final deltaText = (tags != null && tags.isNotEmpty)
        ? tags.first.toString()
        : (metadata['title'] ?? 'Snapshot');

    final whenText =
        backup.createdTime != null ? formatVersionDate(backup.createdTime!) : '';
    final agoText =
        backup.createdTime != null ? formatRelativeTime(backup.createdTime!) : '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 14,
            child: Column(
              children: [
                const SizedBox(height: 5),
                Container(
                  width: isCurrent ? 13 : 10,
                  height: isCurrent ? 13 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent ? c.primary : c.card,
                    border: isCurrent
                        ? Border.all(
                            color: c.primary.withValues(alpha: 0.28), width: 3)
                        : Border.all(color: c.hair, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 2),
                      color: c.hair,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        whenText,
                        style: AppTypography.geist(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Current',
                            style: AppTypography.geist(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: c.onPrimary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        agoText,
                        style: AppTypography.geist(
                          fontSize: 11.5,
                          color: c.ink4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$deviceLabel · $sizeLabel',
                    style: AppTypography.geist(
                      fontSize: 12.5,
                      color: c.ink3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          deltaText,
                          style: AppTypography.geist(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: c.primary,
                          ),
                        ),
                      ),
                      if (!isCurrent) ...[
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () => onRestore(backup),
                          icon: Icon(Icons.undo_rounded, size: 14, color: c.ink2),
                          label: Text(
                            'Restore',
                            style: AppTypography.geist(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: c.ink2,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            side: BorderSide(color: c.hair, width: 1.5),
                            shape: const StadiumBorder(),
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
