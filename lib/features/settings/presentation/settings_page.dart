import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../settings/application/theme_controller.dart';
import '../../settings/data/drive_service.dart';
import '../../settings/data/local_backup_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.themeController,
    required this.driveService,
    required this.localBackupService,
  });

  final ThemeController themeController;
  final DriveService driveService;
  final LocalBackupService localBackupService;

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
            fontSize: 22,
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
                                        fontSize: 12,
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
                    Padding(
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
                              Icons.cloud_sync,
                              color: colorScheme.onPrimaryContainer,
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
                                  lastSync != null
                                      ? 'Last synced: ${_formatTimeAgo(lastSync)}'
                                      : 'Not synced yet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
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
                        ],
                      ),
                    ),
                    // Sync Now Button Area
                    if (isSignedIn) ...[
                      Divider(height: 1, color: colorScheme.outlineVariant),
                      Container(
                        color: colorScheme.surfaceContainerHigh.withAlpha(80),
                        padding: const EdgeInsets.all(16),
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: isSyncing
                              ? null
                              : () async {
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  try {
                                    await widget.driveService.syncFiles();
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Sync completed successfully'),
                                      ),
                                    );
                                  } catch (e) {
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Sync failed: $e'),
                                      ),
                                    );
                                  }
                                },
                          icon: isSyncing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync, size: 18),
                          label: Text(
                            isSyncing ? 'Syncing...' : 'Sync Now',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            side: BorderSide(color: colorScheme.outline),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 8, bottom: 24),
                child: Text(
                  'Automatic sync occurs every 15 minutes when connected to Wi-Fi.',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
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

              // Preferences Section
              _SectionHeader(title: 'Preferences'),
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
                      title: 'About',
                      subtitle: 'Version 2.4.0',
                      onTap: () {
                        // TODO: Show about dialog
                      },
                    ),
                  ],
                ),
              ),
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
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
                      fontSize: 12,
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
      ),
    );
  }
}
