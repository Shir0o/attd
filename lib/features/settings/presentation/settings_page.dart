import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../reports/report_export_page.dart';
import '../../settings/application/app_lock_controller.dart';
import '../../settings/application/theme_controller.dart';
import '../data/google_sheets_service.dart';
import '../data/background_sync_service.dart';
import '../../settings/data/drive_service.dart';
import '../../settings/data/local_backup_service.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../families/presentation/family_list_page.dart';
import '../../hub/presentation/members_page.dart';
import '../../hub/data/event_repository.dart';
import '../../../data/session_repository.dart';

import 'cloud_backup_page.dart';
import 'manage_backup_data_page.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/fluid_loading_border.dart';
import '../../../core/design/widgets/conv_primitives.dart';
import '../../../core/design/widgets/conv_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.themeController,
    required this.driveService,
    required this.localBackupService,
    required this.attendanceRepository,
    required this.eventRepository,
    required this.sessionRepository,
    this.appLockController,
    this.backgroundSyncService,
    this.disableAnimations = false,
  });

  final ThemeController themeController;
  final DriveService driveService;
  final LocalBackupService localBackupService;
  final AttendanceRepository attendanceRepository;
  final EventRepository eventRepository;
  final SessionRepository sessionRepository;
  final AppLockController? appLockController;
  final BackgroundSyncService? backgroundSyncService;
  final bool disableAnimations;


  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _googleSheetsService = GoogleSheetsService();
  final _sheetsUrlController = TextEditingController();
  bool _isSavingUrl = false;
  bool _isInitialLoading = true;
  bool _isOperating = false;
  bool _dataModified = false;

  @override
  void initState() {
    super.initState();
    _loadGoogleSheetsUrl();
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

  void _markDataModified() {
    if (!_dataModified) {
      setState(() => _dataModified = true);
    }
  }

  Future<void> _loadGoogleSheetsUrl() async {
    setState(() => _isInitialLoading = true);
    final prefs = await SharedPreferences.getInstance();
    // Simulate a brief delay to ensure skeleton is visible on first load
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _sheetsUrlController.text = prefs.getString('googleSheetsUrl') ?? '';
      _isInitialLoading = false;
    });
  }

  Future<void> _saveGoogleSheetsUrl(String url) async {
    setState(() => _isSavingUrl = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('googleSheetsUrl', url.trim());
    if (!mounted) return;
    setState(() => _isSavingUrl = false);
  }

  @override
  void dispose() {
    _googleSheetsService.close();
    _sheetsUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && result == null) {
          // If popped without a result (e.g. system back), return our flag
          Navigator.of(context).pop(_dataModified);
        }
      },
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: c.ink),
            onPressed: () => Navigator.of(context).pop(_dataModified),
          ),
          title: const ConvEyebrow('Settings'),
          centerTitle: true,
        ),
        body: FluidLoadingBorder(
          isLoading: _isOperating,
          child: _isInitialLoading
              ? _buildSkeleton(context)
              : ListenableBuilder(
                  listenable: widget.driveService,
                  builder: (context, _) {
                    final isSyncing = widget.driveService.isSyncing;
                    final isSignedIn = widget.driveService.currentUser != null;

                    return ListView(
                      key: const ValueKey('content'),
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
                      children: [
                        Text(
                          'Settings',
                          style: AppTypography.fraunces(
                            fontSize: 32,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.96,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 20),

                    // ── Appearance ───────────────────────────────────────────
                    _SettingSection(
                      title: 'Appearance',
                      children: [
                        ListenableBuilder(
                          listenable: widget.themeController,
                          builder: (context, _) {
                            return _SettingRow(
                              icon: Icons.palette,
                              title: 'Theme Mode',
                              showChevron: false,
                              trailing: DropdownButtonHideUnderline(
                                child: DropdownButton<ThemeMode>(
                                  value: widget.themeController.themeMode,
                                  alignment: Alignment.centerRight,
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: c.ink3,
                                  ),
                                  style: AppTypography.geist(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: c.ink2,
                                  ),
                                  selectedItemBuilder: (BuildContext context) {
                                    return ThemeMode.values.map((ThemeMode mode) {
                                      return Container(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          _getThemeLabel(mode),
                                          textAlign: TextAlign.right,
                                        ),
                                      );
                                    }).toList();
                                  },
                                  items: ThemeMode.values.map((mode) {
                                    return DropdownMenuItem(
                                      value: mode,
                                      alignment: Alignment.centerRight,
                                      child: Text(_getThemeLabel(mode)),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      widget.themeController.updateThemeMode(
                                        value,
                                      );
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Privacy ───────────────────────────────────────────────
                    if (widget.appLockController != null) ...[
                      _SettingSection(
                        title: 'Privacy',
                        children: [
                          _AppLockTile(controller: widget.appLockController!),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── Cloud Sync (Google Drive) ─────────────────────────────
                    _SettingSection(
                      title: 'Cloud Sync (Google Drive)',
                      children: [
                        // Google Drive hero card
                        ConvCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: c.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.cloud_sync,
                                      color: c.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Google Drive',
                                          style: AppTypography.geist(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: c.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isSignedIn
                                              ? (widget.driveService.currentUser
                                                      ?.email ??
                                                  'Signed in')
                                              : 'Not signed in',
                                          style: AppTypography.geist(
                                            fontSize: 13,
                                            color: c.ink3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSignedIn) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: c.present,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (!isSignedIn)
                                FilledButton.icon(
                                  onPressed: _isOperating
                                      ? null
                                      : () async {
                                          final scaffoldMessenger =
                                              ScaffoldMessenger.of(context);
                                          await _performOperation(() async {
                                            try {
                                              await widget.driveService
                                                  .signIn();
                                              if (widget.driveService
                                                      .currentUser !=
                                                  null) {
                                                await widget.driveService
                                                    .setDriveSyncEnabled(true);
                                              }
                                            } catch (e) {
                                              scaffoldMessenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Sign in failed: $e',
                                                  ),
                                                ),
                                              );
                                            }
                                          });
                                        },
                                  icon: const Icon(Icons.login, size: 18),
                                  label: const Text('Sign In'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: c.primary,
                                    foregroundColor: c.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _isOperating
                                            ? null
                                            : () async {
                                                final confirmed =
                                                    await _showConfirmDialog(
                                                  context,
                                                  title: 'Sign Out?',
                                                  message:
                                                      'You will no longer be able to sync with Google Drive until you sign in again.',
                                                  confirmLabel: 'Sign Out',
                                                );
                                                if (confirmed == true) {
                                                  await _performOperation(
                                                    () async {
                                                      await widget.driveService
                                                          .signOut();
                                                    },
                                                  );
                                                }
                                              },
                                        icon: const Icon(Icons.logout, size: 18),
                                        label: const Text('Sign Out'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: c.absent,
                                          side: BorderSide(color: c.absent),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: isSyncing || _isOperating
                                            ? null
                                            : () async {
                                                final scaffoldMessenger =
                                                    ScaffoldMessenger.of(
                                                        context);
                                                final url = _sheetsUrlController
                                                    .text
                                                    .trim();
                                                await _performOperation(
                                                    () async {
                                                  try {
                                                    if (url.isNotEmpty) {
                                                      await Future.wait([
                                                        widget.driveService
                                                            .syncFiles(
                                                          actionTitle:
                                                              'Sheets & Drive Sync',
                                                          tags: [
                                                            'Manual',
                                                            'Sheets',
                                                          ],
                                                        ),
                                                        _googleSheetsService
                                                            .syncAttendance(url),
                                                      ]);
                                                      _markDataModified();
                                                      scaffoldMessenger
                                                          .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Backed up to Drive and Synced to Sheets.',
                                                          ),
                                                        ),
                                                      );
                                                    } else {
                                                      await widget.driveService
                                                          .syncFiles(
                                                        actionTitle:
                                                            'Manual Drive Sync',
                                                        tags: ['Manual'],
                                                      );
                                                      _markDataModified();
                                                      scaffoldMessenger
                                                          .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Sync completed successfully',
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  } on SyncInterruptedException catch (e) {
                                                    scaffoldMessenger
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(e.message),
                                                      ),
                                                    );
                                                  } catch (e) {
                                                    scaffoldMessenger
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                            'Sync failed: $e'),
                                                      ),
                                                    );
                                                  }
                                                });

                                              },
                                        icon: isSyncing
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(Icons.sync, size: 18),
                                        label: Text(
                                          isSyncing ? 'Syncing…' : 'Sync Now',
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: c.primary,
                                          foregroundColor: c.onPrimary,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        if (isSignedIn) ...[
                          _SettingRow(
                            icon: Icons.autorenew,
                            title: 'Background Auto-Sync',
                            subtitle: _formatLastBackgroundSync(
                              widget.driveService.lastBackgroundSyncTime,
                              widget.driveService.lastBackgroundSyncStatus,
                            ),
                            trailing: Switch(
                              value: widget.driveService.isBackgroundSyncEnabled,
                              onChanged: (val) async {
                                await widget.driveService
                                    .setBackgroundSyncEnabled(val);
                                final bgService = widget.backgroundSyncService ??
                                    BackgroundSyncService();
                                if (val) {
                                  await bgService.registerPeriodicSync(
                                    wifiOnly: widget.driveService
                                        .isBackgroundSyncWifiOnly,
                                  );
                                } else {
                                  await bgService.cancelSync();
                                }
                              },
                            ),
                          ),
                          if (widget.driveService.isBackgroundSyncEnabled) ...[
                            _SettingRow(
                              icon: Icons.wifi,
                              title: 'Require Wi-Fi',
                              subtitle:
                                  'Only auto-sync when connected to Wi-Fi',
                              trailing: Switch(
                                value: widget
                                    .driveService.isBackgroundSyncWifiOnly,
                                onChanged: (val) async {
                                  await widget.driveService
                                      .setBackgroundSyncWifiOnly(val);
                                  final bgService =
                                      widget.backgroundSyncService ??
                                          BackgroundSyncService();
                                  await bgService.registerPeriodicSync(
                                    wifiOnly: val,
                                  );
                                },
                              ),
                            ),
                          ],
                          _SettingRow(
                            icon: Icons.history,
                            title: 'Version history',
                            subtitle:
                                'Restore a snapshot · overwrite local or cloud',
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CloudBackupPage(
                                    driveService: widget.driveService,
                                  ),
                                ),
                              );
                              _markDataModified();
                            },
                          ),
                        ],

                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Google Sheets ───────────────────────────────────────────
                    _SettingSection(
                      title: 'Google Sheets Integration',
                      children: [
                        _GoogleSheetsSection(
                          isSavingUrl: _isSavingUrl,
                          sheetsUrlController: _sheetsUrlController,
                          onSave: _saveGoogleSheetsUrl,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Data Management ───────────────────────────────────────
                    _SettingSection(
                      title: 'Data Management',
                      children: [
                        _SettingRow(
                          key: const ValueKey('manage_members_tile'),
                          icon: Icons.people_outline,
                          title: 'Manage Members',
                          subtitle: 'Add, edit, or remove members',
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MembersPage(
                                  attendanceRepository:
                                      widget.attendanceRepository,
                                  sessionRepository: widget.sessionRepository,
                                ),
                              ),
                            );
                            _markDataModified();
                          },
                        ),
                        _SettingRow(
                          key: const ValueKey('manage_families_tile'),
                          icon: Icons.groups_outlined,
                          title: 'Manage Families',
                          subtitle: 'Group members into families',
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FamilyListPage(
                                  repository: widget.attendanceRepository,
                                  disableAnimations: widget.disableAnimations,
                                ),
                              ),
                            );
                            if (mounted) {
                              _markDataModified();
                            }
                          },
                        ),
                        _SettingRow(
                          key: const ValueKey('manage_backup_data_tile'),
                          icon: Icons.cleaning_services,
                          title: 'Manage Backup Data',
                          subtitle: 'Clean up hidden or orphaned records',
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ManageBackupDataPage(
                                  attendanceRepository:
                                      widget.attendanceRepository,
                                  eventRepository: widget.eventRepository,
                                  sessionRepository: widget.sessionRepository,
                                ),
                              ),
                            );
                            _markDataModified();
                          },
                        ),
                        _SettingRow(
                          icon: Icons.save,
                          title: 'Backup to Local Storage',
                          subtitle: 'Create a full backup on this device',
                          onTap: () async {
                            final scaffoldMessenger =
                                ScaffoldMessenger.of(context);
                            try {
                              await widget.localBackupService.createBackup();
                            } catch (e) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text('Backup failed: $e'),
                                ),
                              );
                            }
                          },
                        ),
                        _SettingRow(
                          icon: Icons.summarize,
                          title: 'Advanced Reporting',
                          subtitle: 'Filter and export custom reports',
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ReportExportPage(
                                  sessionRepository: widget.sessionRepository,
                                ),
                              ),
                            );
                          },
                        ),
                        _SettingRow(
                          icon: Icons.ios_share,
                          title: 'Export Report',
                          subtitle: 'Download CSV',
                          onTap: () async {
                            final scaffoldMessenger =
                                ScaffoldMessenger.of(context);
                            try {
                              await widget.localBackupService.exportData();
                            } catch (e) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text('Export failed: $e'),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Information ───────────────────────────────────────────
                    _SettingSection(
                      title: 'Information',
                      children: [
                        _SettingRow(
                          icon: Icons.feedback_outlined,
                          title: 'Feedback & Support',
                          subtitle: 'Report a bug or request a feature',
                            onTap: () async {
                              String? encodeQueryParameters(Map<String, String> params) {
                                return params.entries
                                    .map((MapEntry<String, String> e) =>
                                        '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
                                    .join('&');
                              }

                              final Uri emailLaunchUri = Uri(
                                scheme: 'mailto',
                                path: 'twangdeveloper@gmail.com',
                                query: encodeQueryParameters(<String, String>{
                                  'subject': 'Attendance Tracker Feedback',
                                  'body':
                                      'App Version: 1.2.0+13\n\nDescribe your feedback or bug here...',
                                }),
                              );

                              try {
                                await launchUrl(
                                  emailLaunchUri,
                                  mode: LaunchMode.externalApplication,
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Could not launch email app'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          _SettingRow(
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
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(28),
                                  ),
                                ),
                                builder: (context) =>
                                    DraggableScrollableSheet(
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
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: colorScheme
                                                          .onSurface,
                                                    ),
                                              ),
                                              const SizedBox(height: 24),
                                              Text(
                                                'Attendance Tracker is designed with privacy as a core principle. Your data belongs to you.',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      color:
                                                          colorScheme.primary,
                                                      fontWeight:
                                                          FontWeight.w500,
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
                                                Icons.bug_report_outlined,
                                                'Anonymized Error Reporting',
                                                'We use Firebase Crashlytics to catch bugs and improve app stability. This service collects anonymous technical data about app crashes (such as device model and stack traces). No personal information is ever sent.',
                                              ),
                                              _buildPolicyPoint(
                                                context,
                                                Icons.cloud_off,
                                                'No Advertising Tracking',
                                                'We do not use any advertising identifiers or tracking pixels. Your usage of the app for any purpose other than technical stability is completely private and anonymous.',
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
                                                  'Effective Date: April 2, 2026',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
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
                          _SettingRow(
                            icon: Icons.info_outline,
                            title: 'About',
                            subtitle: 'Version 1.2.0+13',
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                backgroundColor: colorScheme.surface,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(28),
                                  ),
                                ),
                                builder: (context) =>
                                    DraggableScrollableSheet(
                                  initialChildSize: 0.6,
                                  minChildSize: 0.4,
                                  maxChildSize: 0.9,
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
                                              Center(
                                                child: Container(
                                                  width: 80,
                                                  height: 80,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      20,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                          alpha: 0.1,
                                                        ),
                                                        blurRadius: 10,
                                                        spreadRadius: 2,
                                                      ),
                                                    ],
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      20,
                                                    ),
                                                    child: Image.asset(
                                                      'assets/icon/icon.png',
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              Center(
                                                child: Text(
                                                  'Attendance Tracker',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: colorScheme
                                                            .onSurface,
                                                      ),
                                                ),
                                              ),
                                              Center(
                                                child: Text(
                                                  'Version 1.2.0+13',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(height: 32),
                                              _buildPolicyPoint(
                                                context,
                                                Icons.copyright,
                                                'Legalese',
                                                '© 2026 Attendance Tracker Contributors. All rights reserved.',
                                              ),
                                              const SizedBox(height: 48),
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
                    const SizedBox(height: 32),
                    Center(
                      child: ConvEyebrow('Attendance · Version 1.2.0+13'),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
        ),
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

  Widget _buildSkeleton(BuildContext context) {
    return ListView(
      key: const ValueKey('settings_skeleton'),
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
      children: [
        AppShimmer(
          width: 160,
          height: 36,
          borderRadius: BorderRadius.circular(8),
          disableAnimations: widget.disableAnimations,
        ),
        const SizedBox(height: 20),
        _buildSkeletonSection(context, 1),
        const SizedBox(height: 24),
        _buildSkeletonSection(context, 1, hasButtons: true),
        const SizedBox(height: 24),
        _buildSkeletonSection(context, 4),
        const SizedBox(height: 24),
        _buildSkeletonSection(context, 3),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildSkeletonSection(BuildContext context, int tileCount,
      {bool hasButtons = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: AppShimmer(
            width: 90,
            height: 11,
            borderRadius: BorderRadius.circular(4),
            disableAnimations: widget.disableAnimations,
          ),
        ),
        if (hasButtons) ...[
          _buildSkeletonCard(context, withDot: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppShimmer(
                  height: 44,
                  width: double.infinity,
                  borderRadius: BorderRadius.circular(14),
                  disableAnimations: widget.disableAnimations,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppShimmer(
                  height: 44,
                  width: double.infinity,
                  borderRadius: BorderRadius.circular(14),
                  disableAnimations: widget.disableAnimations,
                ),
              ),
            ],
          ),
        ] else
          for (int i = 0; i < tileCount; i++) ...[
            _buildSkeletonTile(context),
            if (i < tileCount - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildSkeletonCard(BuildContext context, {bool withDot = false}) {
    return ConvCard(
      padding: const EdgeInsets.all(18),
      child: _skeletonRow(context, dense: false, withDot: withDot),
    );
  }

  Widget _buildSkeletonTile(BuildContext context) {
    return ConvCardSoft(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: _skeletonRow(context, dense: true),
    );
  }

  Widget _skeletonRow(
    BuildContext context, {
    required bool dense,
    bool withDot = false,
  }) {
    final size = dense ? 40.0 : 44.0;
    return Row(
      children: [
        AppShimmer(
          width: size,
          height: size,
          borderRadius: BorderRadius.circular(dense ? 12 : 14),
          disableAnimations: widget.disableAnimations,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppShimmer(
                width: 140,
                height: 14,
                borderRadius: BorderRadius.circular(4),
                disableAnimations: widget.disableAnimations,
              ),
              const SizedBox(height: 8),
              AppShimmer(
                width: 200,
                height: 12,
                borderRadius: BorderRadius.circular(4),
                disableAnimations: widget.disableAnimations,
              ),
            ],
          ),
        ),
        if (withDot) ...[
          const SizedBox(width: 8),
          AppShimmer(
            width: 8,
            height: 8,
            borderRadius: BorderRadius.circular(4),
            disableAnimations: widget.disableAnimations,
          ),
        ],
      ],
    );
  }

  Future<bool?> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
              borderRadius: BorderRadius.circular(24),
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

// ── Google Sheets Section (inside Cloud Sync card) ────────────────────────────

class _GoogleSheetsSection extends StatelessWidget {
  const _GoogleSheetsSection({
    required this.isSavingUrl,
    required this.sheetsUrlController,
    required this.onSave,
  });

  final bool isSavingUrl;
  final TextEditingController sheetsUrlController;
  final ValueChanged<String> onSave;

  @override
  Widget build(BuildContext context) {
    // The Apps Script code to copy
    const script = r'''function doGet(e) {
  return ContentService.createTextOutput("The Attendance API is running successfully.");
}

function doPost(e) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    let sheet = ss.getSheetByName("Raw Logs");
    
    // 1. Setup Sheet and Headers
    if (!sheet) {
      sheet = ss.insertSheet("Raw Logs");
    }
    
    // Lock in the 6-column header. Changed "Points" to "Attendance Value"
    sheet.getRange(1, 1, 1, 6).setValues([["Sync Time", "Meeting Date", "Event", "Member", "Is Present", "Attendance Value"]])
         .setFontWeight("bold").setBackground("#f3f3f3");
    sheet.setFrozenRows(1);

    const data = JSON.parse(e.postData.contents);
    const syncTime = data.date || new Date().toISOString(); 
    
    let newData = [];

    // 2. Process incoming app records (No merging, just mapping)
    data.records.forEach(record => {
      // If a record is explicitly marked as deleted in the app's DB, we just skip it
      const isDeleted = (record.status && record.status.toLowerCase() === 'deleted') || 
                        (record.action && record.action.toLowerCase() === 'delete');
      
      if (!isDeleted) {
        let meetingDate = "";
        let event = "";
        let member = record.name; 

        // Extract clean names/dates
        const match = record.name.match(/\[(.*?)\]\s*(.*?)\s*-\s*(.*)/);
        if (match) {
          meetingDate = match[1].trim();
          event = match[2].trim();
          member = match[3].trim();
        }

        // Generate the boolean and the numeric value for the Pivot Table
        const isPresent = (record.status && record.status.toLowerCase() === 'present');
        const attendanceValue = isPresent ? 1 : 0; 
        
        // Push cleanly formatted row to our array
        newData.push([syncTime, meetingDate, event, member, isPresent, attendanceValue]);
      }
    });

    // 3. WIPE AND REPLACE
    // Clear all existing data (leaving the header untouched)
    if (sheet.getLastRow() > 1) {
      sheet.getRange(2, 1, sheet.getLastRow() - 1, 6).clearContent();
    }
    
    // Dump the fresh app database into the sheet
    if (newData.length > 0) {
      sheet.getRange(2, 1, newData.length, 6).setValues(newData);
    }

    return ContentService.createTextOutput(JSON.stringify({
      "status": "success", 
      "totalRows": newData.length,
      "message": "Sheet wiped and fully replaced."
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      "status": "error", 
      "message": error.message
    })).setMimeType(ContentService.MimeType.JSON);
  }
}''';

    final c = context.conv;
    return ConvCardSoft(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: script));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Boilerplate copied to clipboard!'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Apps Script Boilerplate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: c.onPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '1. Create a Google Sheet and open Extensions > Apps Script.\n'
            '2. Paste the copied script, Deploy as Web App (Anyone).\n'
            '3. Paste the deployment URL below.',
            style: AppTypography.geist(
              fontSize: 14,
              color: c.ink3,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: sheetsUrlController,
            decoration: InputDecoration(
              labelText: 'Web App URL',
              hintText: 'https://script.google.com/macros/s/...',
              border: const OutlineInputBorder(),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sheetsUrlController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      tooltip: 'Clear URL',
                      onPressed: () {
                        sheetsUrlController.clear();
                        onSave('');
                      },
                    ),
                  if (isSavingUrl)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: Padding(
                        padding: EdgeInsets.all(4.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
            onChanged: onSave,
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

class _SettingSection extends StatelessWidget {
  const _SettingSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: ConvEyebrow(title),
        ),
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Reusable leading icon — primary-tinted rounded square (JSX SettingRow icon).
class _SettingLeadingIcon extends StatelessWidget {
  const _SettingLeadingIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: c.primary, size: 20),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return ConvCardSoft(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _SettingLeadingIcon(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.geist(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.geist(fontSize: 12, color: c.ink3),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (showChevron)
            Icon(Icons.chevron_right, color: c.ink3, size: 22),
        ],
      ),
    );
  }
}

class _AppLockTile extends StatefulWidget {
  const _AppLockTile({required this.controller});

  final AppLockController controller;

  @override
  State<_AppLockTile> createState() => _AppLockTileState();
}

class _AppLockTileState extends State<_AppLockTile> {
  bool _supported = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    _probe();
  }

  Future<void> _probe() async {
    final ok = await widget.controller.canUseAppLock();
    if (!mounted) return;
    setState(() => _supported = ok);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = value
        ? await widget.controller.enable()
        : await widget.controller.disable();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Authentication failed. App lock not enabled.'
                : 'Authentication failed. App lock still enabled.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      icon: Icons.lock_outline,
      title: 'App Lock',
      subtitle: _supported
          ? 'Require biometrics or device passcode to open Attendance'
          : 'Set up biometrics or a device passcode to use App Lock',
      trailing: Switch(
        value: widget.controller.isEnabled,
        onChanged: (!_supported || _busy) ? null : _toggle,
      ),
    );
  }
}

String _formatLastBackgroundSync(DateTime? time, String? status) {
  if (time == null) {
    if (status != null && status.isNotEmpty) {
      return 'Status: $status';
    }
    return 'Periodic background backup every 12 hours';
  }
  final now = DateTime.now();
  final diff = now.difference(time);
  String timeStr;
  if (diff.inMinutes < 1) {
    timeStr = 'Just now';
  } else if (diff.inMinutes < 60) {
    timeStr = '${diff.inMinutes}m ago';
  } else if (diff.inHours < 24) {
    timeStr = '${diff.inHours}h ago';
  } else {
    timeStr = '${diff.inDays}d ago';
  }
  return 'Last auto-synced $timeStr${status != null ? ' · $status' : ''}';
}

