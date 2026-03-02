import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../settings/application/theme_controller.dart';
import '../../settings/data/drive_service.dart';
import '../../settings/data/local_backup_service.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../hub/presentation/members_page.dart';

import 'cloud_backup_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.themeController,
    required this.driveService,
    required this.localBackupService,
    required this.attendanceRepository,
  });

  final ThemeController themeController;
  final DriveService driveService;
  final LocalBackupService localBackupService;
  final AttendanceRepository attendanceRepository;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.driveService,
        builder: (context, _) {
          final isSyncing = widget.driveService.isSyncing;
          final isSignedIn = widget.driveService.currentUser != null;
          final lastSync = widget.driveService.lastSyncTime;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Appearance Section
              _SectionHeader(title: 'Appearance'),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListenableBuilder(
                      listenable: widget.themeController,
                      builder: (context, _) {
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
                                  Icons.palette,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Theme Mode',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _getThemeLabel(widget.themeController.themeMode),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DropdownButton<ThemeMode>(
                                value: widget.themeController.themeMode,
                                items: ThemeMode.values.map((mode) {
                                  return DropdownMenuItem(
                                    value: mode,
                                    child: Text(_getThemeLabel(mode)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  widget.themeController.updateThemeMode(value);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Cloud Sync Section
              _SectionHeader(title: 'Cloud Sync'),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.cloud_sync,
                      title: 'Google Drive Sync',
                      subtitle: lastSync != null
                          ? 'Last synced: ${_formatTimeAgo(lastSync)}'
                          : 'Not synced yet',
                      trailing: Switch(
                        value: isSignedIn,
                        activeThumbColor: colorScheme.primary,
                        onChanged: (value) async {
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          try {
                            if (value) {
                              await widget.driveService.signIn();
                            } else {
                              await widget.driveService.signOut();
                            }
                          } catch (e) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                      ),
                    ),
                    if (isSignedIn) ...[
                      Divider(height: 1, color: colorScheme.outlineVariant),
                      _SettingsTile(
                        icon: Icons.history,
                        title: 'Cloud Version History',
                        subtitle: 'View and restore previous cloud snapshots',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => CloudBackupPage(
                                    driveService: widget.driveService,
                                  ),
                            ),
                          );
                        },
                      ),
                      Divider(height: 1, color: colorScheme.outlineVariant),
                      _SettingsTile(
                        icon: Icons.upload_file,
                        title: 'Overwrite Cloud',
                        subtitle: 'Force upload local data to Google Drive',
                        onTap: isSyncing
                            ? null
                            : () async {
                                final confirmed = await _showConfirmDialog(
                                  context,
                                  title: 'Overwrite Cloud Data?',
                                  message:
                                      'This will replace all data on your Google Drive with the data currently on this device. Use this if you have deleted items that keep coming back.',
                                  confirmLabel: 'Overwrite',
                                );
                                if (confirmed == true) {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  try {
                                    await widget.driveService
                                        .overwriteCloudWithLocal();
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Cloud data overwritten'),
                                      ),
                                    );
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                      ),
                      Divider(height: 1, color: colorScheme.outlineVariant),
                      _SettingsTile(
                        icon: Icons.download_for_offline,
                        title: 'Overwrite Local',
                        subtitle: 'Force download data from Google Drive',
                        onTap: isSyncing
                            ? null
                            : () async {
                                final confirmed = await _showConfirmDialog(
                                  context,
                                  title: 'Overwrite Local Data?',
                                  message:
                                      'This will replace all data on this device with the data from your Google Drive. Current local changes will be lost.',
                                  confirmLabel: 'Overwrite',
                                );
                                if (confirmed == true) {
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  try {
                                    await widget.driveService
                                        .overwriteLocalWithCloud();
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Local data overwritten'),
                                      ),
                                    );
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                      ),
                      Divider(height: 1, color: colorScheme.outlineVariant),
                      _SettingsTile(
                        icon: Icons.sync,
                        title: 'Sync Now',
                        subtitle: isSyncing
                            ? 'Syncing... this may take a while'
                            : 'Manually trigger a cloud sync',
                        trailing: isSyncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : null,
                        onTap: isSyncing
                            ? null
                            : () async {
                                final scaffoldMessenger =
                                    ScaffoldMessenger.of(context);
                                try {
                                  await widget.driveService.syncFiles();
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Sync completed successfully'),
                                    ),
                                  );
                                } catch (e) {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(content: Text('Sync failed: $e')),
                                  );
                                }
                              },
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 8, bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Automatic sync occurs every 15 minutes when connected to Wi-Fi.',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Local Storage Section
              _SectionHeader(title: 'Local Storage'),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.save,
                      title: 'Backup to Local Storage',
                      subtitle: 'Create a full backup on this device',
                      onTap: () async {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        try {
                          await widget.localBackupService.createBackup();
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(content: Text('Backup failed: $e')),
                          );
                        }
                      },
                    ),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    _SettingsTile(
                      icon: Icons.ios_share,
                      title: 'Export Report',
                      subtitle: 'Download spreadsheet (CSV) format',
                      onTap: () async {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        try {
                          await widget.localBackupService.exportData();
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(content: Text('Export failed: $e')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Management Section
              _SectionHeader(title: 'Management'),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.people_outline,
                      title: 'Manage Members',
                      subtitle: 'Add, edit, or remove members',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => MembersPage(
                                  attendanceRepository:
                                      widget.attendanceRepository,
                                ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Privacy & Data Section
              _SectionHeader(title: 'Privacy & Data'),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.security,
                      title: 'Privacy Policy',
                      subtitle: 'How your data is handled',
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          backgroundColor: colorScheme.surface,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(28)),
                          ),
                          builder:
                              (context) => DraggableScrollableSheet(
                                initialChildSize: 0.9,
                                minChildSize: 0.5,
                                maxChildSize: 0.95,
                                expand: false,
                                builder: (context, scrollController) {
                                  return Column(
                                    children: [
                                      const SizedBox(height: 12),
                                      Container(
                                        width: 32,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.4),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      Expanded(
                                        child: ListView(
                                          controller: scrollController,
                                          padding: const EdgeInsets.all(24),
                                          children: [
                                            Text(
                                              'Privacy Policy',
                                              style: theme.textTheme.headlineMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: colorScheme.onSurface,
                                                  ),
                                            ),
                                            const SizedBox(height: 24),
                                            Text(
                                              'Attendance Tracker is designed with privacy as a core principle. Your data belongs to you.',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    color: colorScheme.primary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                            const SizedBox(height: 32),
                                            _buildPolicyPoint(
                                              context,
                                              Icons.storage,
                                              'Local-First Storage',
                                              'All your attendance records, member lists, and event configurations are stored locally on your device database. We do not maintain any central servers to store your information.',
                                            ),
                                            _buildPolicyPoint(
                                              context,
                                              Icons.cloud_off,
                                              'No Third-Party Tracking',
                                              'We do not use any analytics, tracking pixels, or advertising identifiers. Your usage of the app is completely private and anonymous.',
                                            ),
                                            _buildPolicyPoint(
                                              context,
                                              Icons.folder_shared,
                                              'User-Controlled Sync',
                                              'Google Drive Sync uses your personal Google account storage only. The app only accesses its own dedicated folder and does not see other files in your Drive.',
                                            ),
                                            _buildPolicyPoint(
                                              context,
                                              Icons.visibility_off,
                                              'Developer Access',
                                              'The application developers have no technical means to access, view, or modify your attendance data. All synchronization and backups are encrypted via your Google account.',
                                            ),
                                            const SizedBox(height: 48),
                                            Center(
                                              child: Text(
                                                'Effective Date: February 25, 2026',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // About Section
              _SectionHeader(title: 'About'),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.info,
                      title: 'Version',
                      subtitle: '2.4.0',
                      onTap: () {
                        // TODO: Show about details
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],
          );
        },
      ),
    );
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mins ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  Future<bool?> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(confirmLabel),
              ),
            ],
          ),
    );
  }

  Widget _buildPolicyPoint(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.onSurfaceVariant),
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
            trailing ??
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                  size: 24,
                ),
          ],
        ),
      ),
    );
  }
}
