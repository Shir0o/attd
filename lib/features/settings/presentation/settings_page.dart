import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../settings/data/drive_service.dart';
import '../../settings/data/local_backup_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.driveService,
    required this.localBackupService,
  });

  final DriveService driveService;
  final LocalBackupService localBackupService;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Theme Colors
  static const primaryColor = Color(0xFF6750A4);
  static const surfaceColor = Color(0xFFFEF7FF);
  static const onSurfaceColor = Color(0xFF1D1B20);
  static const onSurfaceVariantColor = Color(0xFF49454F);
  static const surfaceContainerColor = Color(0xFFF3EDF7);
  static const surfaceContainerHighColor = Color(0xFFECE6F0);
  static const primaryContainerColor = Color(0xFFEADDFF);
  static const onPrimaryContainerColor = Color(0xFF21005D);
  static const outlineColor = Color(0xFF79747E);
  static const outlineVariantColor = Color(0xFFCAC4D0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: onSurfaceColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: onSurfaceColor,
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
              // Cloud Sync Section
              _SectionHeader(title: 'Cloud Sync'),
              Container(
                decoration: BoxDecoration(
                  color: surfaceContainerColor,
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
                            decoration: const BoxDecoration(
                              color: primaryContainerColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_sync,
                              color: onPrimaryContainerColor,
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
                                    color: onSurfaceColor,
                                  ),
                                ),
                                Text(
                                  lastSync != null
                                      ? 'Last synced: ${_formatTimeAgo(lastSync)}'
                                      : 'Not synced yet',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: onSurfaceVariantColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isSignedIn,
                            activeThumbColor: primaryColor,
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
                      const Divider(height: 1, color: outlineVariantColor),
                      Container(
                        color: surfaceContainerHighColor.withAlpha(80),
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
                            foregroundColor: primaryColor,
                            side: const BorderSide(color: outlineColor),
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
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 8, bottom: 24),
                child: Text(
                  'Automatic sync occurs every 15 minutes when connected to Wi-Fi.',
                  style: TextStyle(fontSize: 12, color: onSurfaceVariantColor),
                ),
              ),

              // Local Storage Section
              _SectionHeader(title: 'Local Storage'),
              Container(
                decoration: BoxDecoration(
                  color: surfaceContainerColor,
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
                    const Divider(height: 1, color: outlineVariantColor),
                    _SettingsTile(
                      icon: Icons.ios_share,
                      title: 'Export Data',
                      subtitle: 'Download CSV or JSON format',
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
                  color: surfaceContainerColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.palette,
                      title: 'Appearance',
                      subtitle: 'Light theme',
                      onTap: () {
                        // TODO: Implement theme toggle
                      },
                    ),
                    const Divider(height: 1, color: outlineVariantColor),
                    _SettingsTile(
                      icon: Icons.notifications,
                      title: 'Notifications',
                      subtitle: 'On',
                      onTap: () {
                        // TODO: Implement notifications toggle
                      },
                    ),
                    const Divider(height: 1, color: outlineVariantColor),
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
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF6750A4), // primary
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF49454F)), // onSurfaceVariant
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF1D1B20), // onSurface
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF49454F), // onSurfaceVariant
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF49454F),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
