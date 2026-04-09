import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/application/theme_controller.dart';
import '../../settings/data/drive_service.dart';
import '../../settings/data/local_backup_service.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../hub/presentation/members_page.dart';
import '../../hub/data/event_repository.dart';
import '../../../data/session_repository.dart';

import 'cloud_backup_page.dart';
import 'manage_backup_data_page.dart';
import '../../../core/design/app_shimmer.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.themeController,
    required this.driveService,
    required this.localBackupService,
    required this.attendanceRepository,
    required this.eventRepository,
    required this.sessionRepository,
    this.disableAnimations = false,
  });

  final ThemeController themeController;
  final DriveService driveService;
  final LocalBackupService localBackupService;
  final AttendanceRepository attendanceRepository;
  final EventRepository eventRepository;
  final SessionRepository sessionRepository;
  final bool disableAnimations;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String _sheetsUrlKey = 'google_sheets_webhook_url';
  final _sheetsUrlController = TextEditingController();
  bool _isInitialLoading = true;
  bool _dataModified = false;

  @override
  void initState() {
    super.initState();
    debugPrint('DEBUG: SettingsPage.initState START');
    _loadGoogleSheetsUrl();
    _refreshLatest();
  }

  Future<void> _loadGoogleSheetsUrl() async {
    debugPrint('DEBUG: SettingsPage._loadGoogleSheetsUrl START');
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_sheetsUrlKey);
    if (mounted) {
      setState(() => _sheetsUrlController.text = url ?? '');
    }
    debugPrint('DEBUG: SettingsPage._loadGoogleSheetsUrl END');
  }

  Future<void> _refreshLatest() async {
    debugPrint('DEBUG: SettingsPage._refreshLatest START');
    
    // Minimum wait for skeleton
    final delay = widget.disableAnimations ? Duration.zero : const Duration(milliseconds: 800);
    
    await Future.delayed(delay);
    
    if (mounted) {
      setState(() {
        _isInitialLoading = false;
      });
      debugPrint('DEBUG: SettingsPage._refreshLatest END, _isInitialLoading=false');
    }
  }

  void _markDataModified() {
    setState(() => _dataModified = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _dataModified) {
          // If data was modified, refresh the parent
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: RepaintBoundary(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: _isInitialLoading
                ? _buildSkeleton(context)
                : CustomScrollView(
                    key: const ValueKey('content'),
                    slivers: [
                      SliverAppBar(
                        backgroundColor: colorScheme.surface.withValues(
                          alpha: 0.95,
                        ),
                        surfaceTintColor: Colors.transparent,
                        pinned: true,
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          color: colorScheme.onSurface,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        title: Text(
                          'Settings',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        centerTitle: true,
                      ),

                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            const SizedBox(height: 12),
                            
                            // ── Appearance ─────────────────────────────────────────────
                            _SectionHeader(title: 'Appearance'),
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.palette_outlined,
                                        color: colorScheme.onPrimaryContainer,
                                        size: 20,
                                      ),
                                    ),
                                    title: const Text('Theme Mode'),
                                    trailing: DropdownButton<ThemeMode>(
                                      value: widget.themeController.themeMode,
                                      onChanged: (mode) {
                                        if (mode != null) {
                                          widget.themeController.updateThemeMode(mode);
                                        }
                                      },
                                      items: const [
                                        DropdownMenuItem(
                                          value: ThemeMode.system,
                                          child: Text('System'),
                                        ),
                                        DropdownMenuItem(
                                          value: ThemeMode.light,
                                          child: Text('Light'),
                                        ),
                                        DropdownMenuItem(
                                          value: ThemeMode.dark,
                                          child: Text('Dark'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── Data Management ───────────────────────────────────────
                            _SectionHeader(title: 'Data Management'),
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  _SettingsTile(
                                    key: const ValueKey('manage_members_tile'),
                                    icon: Icons.people_outline,
                                    title: 'Manage Members',
                                    subtitle: 'Add, edit, or remove members',
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => MembersPage(
                                            attendanceRepository: widget.attendanceRepository,
                                            sessionRepository: widget.sessionRepository,
                                          ),
                                        ),
                                      );
                                      _markDataModified();
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  _SettingsTile(
                                    key: const ValueKey('manage_backup_data_tile'),
                                    icon: Icons.cleaning_services,
                                    title: 'Manage Backup Data',
                                    subtitle: 'Clean up hidden or orphaned records',
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ManageBackupDataPage(
                                            attendanceRepository: widget.attendanceRepository,
                                            eventRepository: widget.eventRepository,
                                            sessionRepository: widget.sessionRepository,
                                          ),
                                        ),
                                      );
                                      _markDataModified();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── Backup & Sync ──────────────────────────────────────────
                            _SectionHeader(title: 'Backup & Sync'),
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  _SettingsTile(
                                    icon: Icons.cloud_sync_outlined,
                                    title: 'Google Drive Sync',
                                    subtitle: 'Sync data across devices',
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => CloudBackupPage(driveService: widget.driveService)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 48),
                          ]),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: colorScheme.surface,
          pinned: true,
          title: AppShimmer(
            width: 100,
            height: 24,
            borderRadius: BorderRadius.circular(12),
          ),
          centerTitle: true,
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: AppShimmer(
                width: double.infinity,
                height: 72,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            childCount: 6,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
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
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
