import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/application/theme_controller.dart';
import '../data/google_sheets_service.dart';
import '../../settings/data/drive_service.dart';
import '../../settings/data/local_backup_service.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../hub/presentation/members_page.dart';
import '../../hub/data/event_repository.dart';
import '../../../data/session_repository.dart';

import 'cloud_backup_page.dart';
import 'manage_backup_data_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.themeController,
    required this.driveService,
    required this.localBackupService,
    required this.attendanceRepository,
    required this.eventRepository,
    required this.sessionRepository,
  });

  final ThemeController themeController;
  final DriveService driveService;
  final LocalBackupService localBackupService;
  final AttendanceRepository attendanceRepository;
  final EventRepository eventRepository;
  final SessionRepository sessionRepository;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _googleSheetsService = GoogleSheetsService();
  final _sheetsUrlController = TextEditingController();
  bool _isSavingUrl = false;

  @override
  void initState() {
    super.initState();
    _loadGoogleSheetsUrl();
  }

  Future<void> _loadGoogleSheetsUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sheetsUrlController.text = prefs.getString('googleSheetsUrl') ?? '';
    });
  }

  Future<void> _saveGoogleSheetsUrl(String url) async {
    setState(() => _isSavingUrl = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('googleSheetsUrl', url.trim());
    setState(() => _isSavingUrl = false);
  }

  @override
  void dispose() {
    _sheetsUrlController.dispose();
    super.dispose();
  }

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
                                      _getThemeLabel(
                                        widget.themeController.themeMode,
                                      ),
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
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
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
                              builder: (_) => CloudBackupPage(
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
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
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
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                        onTap: isSyncing
                            ? null
                            : () async {
                                final scaffoldMessenger = ScaffoldMessenger.of(
                                  context,
                                );
                                final url = _sheetsUrlController.text.trim();

                                try {
                                  if (url.isNotEmpty) {
                                    await Future.wait([
                                      widget.driveService.syncFiles(),
                                      _googleSheetsService.syncAttendance(url),
                                    ]);
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Backed up to Drive and Synced to Sheets.',
                                        ),
                                      ),
                                    );
                                  } else {
                                    await widget.driveService.syncFiles();
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Sync completed successfully',
                                        ),
                                      ),
                                    );
                                  }
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
              const SizedBox(height: 24),

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
                      subtitle: 'Download CSV',
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

              // Google Sheets Section
              _SectionHeader(title: 'Connect to Google Sheets'),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        const script = r'''function doGet(e) {
  return ContentService.createTextOutput("The Attendance API is running successfully.");
}

function doPost(e) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    let sheet = ss.getSheetByName("Raw Logs");
    
    // 1. Setup Sheet if it doesn't exist (Changed 5 columns to 6)
    if (!sheet) {
      sheet = ss.insertSheet("Raw Logs");
      sheet.appendRow(["Sync Time", "Meeting Date", "Event", "Member", "Is Present", "Points"]);
      sheet.getRange(1, 1, 1, 6).setFontWeight("bold").setBackground("#f3f3f3");
      sheet.setFrozenRows(1);
    }

    const data = JSON.parse(e.postData.contents);
    const syncTime = data.date; 
    
    // 2. Read existing data into memory 
    const existingData = sheet.getDataRange().getDisplayValues();
    const headers = existingData.shift() || ["Sync Time", "Meeting Date", "Event", "Member", "Is Present", "Points"];
    
    // 3. Map existing records by a Unique Key
    let rowMap = new Map();
    existingData.forEach(row => {
      const key = `${row[1]}|${row[2]}|${row[3]}`; 
      rowMap.set(key, row);
    });

    // 4. Process incoming app records
    data.records.forEach(record => {
      let meetingDate = "";
      let event = "";
      let member = record.name; 

      const match = record.name.match(/\[(.*?)\]\s*(.*?)\s*-\s*(.*)/);
      if (match) {
        meetingDate = match[1].trim();
        event = match[2].trim();
        member = match[3].trim();
      }

      const key = match ? `${meetingDate}|${event}|${member}` : record.name;

      const isDeleted = (record.status && record.status.toLowerCase() === 'deleted') || 
                        (record.action && record.action.toLowerCase() === 'delete');

      if (isDeleted) {
        rowMap.delete(key);
      } else {
        // ADD / EDIT: Generate the boolean AND the numeric point
        const isPresent = (record.status && record.status.toLowerCase() === 'present');
        const points = isPresent ? 1 : 0; // The magic fix for your Pivot Table
        
        // Push 6 items to the array instead of 5
        rowMap.set(key, [syncTime, meetingDate, event, member, isPresent, points]);
      }
    });

    // 5. Reconstruct the finalized data array
    const newData = Array.from(rowMap.values());
    
    // 6. Write back to the sheet
    // Clear old data first (Changed 5 to 6 to clear the new column too)
    if (sheet.getLastRow() > 1) {
      sheet.getRange(2, 1, sheet.getLastRow() - 1, 6).clearContent();
    }
    
    // Write the cleanly synced data (Changed 5 to 6)
    if (newData.length > 0) {
      sheet.getRange(2, 1, newData.length, 6).setValues(newData);
    }

    return ContentService.createTextOutput(JSON.stringify({
      "status": "success", 
      "totalRows": newData.length
    })).setMimeType(ContentService.MimeType.JSON);

  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({
      "status": "error", 
      "message": error.message
    })).setMimeType(ContentService.MimeType.JSON);
  }
}''';
                        await Clipboard.setData(
                          const ClipboardData(text: script),
                        );
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
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '1. Create a Google Sheet and open Extensions > Apps Script.\n'
                      '2. Paste the copied script, Deploy as Web App (Anyone).\n'
                      '3. Paste the deployment URL below.',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _sheetsUrlController,
                      decoration: InputDecoration(
                        labelText: 'Web App URL',
                        hintText: 'https://script.google.com/macros/s/...',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_sheetsUrlController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                tooltip: 'Clear URL',
                                onPressed: () {
                                  _sheetsUrlController.clear();
                                  _saveGoogleSheetsUrl('');
                                },
                              ),
                            if (_isSavingUrl)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      onChanged: (value) => _saveGoogleSheetsUrl(value),
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
                            builder: (_) => MembersPage(
                              attendanceRepository: widget.attendanceRepository,
                            ),
                          ),
                        );
                      },
                    ),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    _SettingsTile(
                      icon: Icons.cleaning_services,
                      title: 'Manage Backup Data',
                      subtitle: 'Clean up hidden or orphaned records',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ManageBackupDataPage(
                              attendanceRepository: widget.attendanceRepository,
                              eventRepository: widget.eventRepository,
                              sessionRepository: widget.sessionRepository,
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
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                          ),
                          builder: (context) => DraggableScrollableSheet(
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
                                      borderRadius: BorderRadius.circular(2),
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
                      icon: Icons.info_outline,
                      title: 'App Version',
                      subtitle: '2.4.0',
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
                          builder: (context) => DraggableScrollableSheet(
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
                                      borderRadius: BorderRadius.circular(2),
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
                                                  BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.1),
                                                  blurRadius: 10,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(20),
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
                                            style: theme
                                                .textTheme
                                                .headlineMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: colorScheme.onSurface,
                                                ),
                                          ),
                                        ),
                                        Center(
                                          child: Text(
                                            'Version 2.4.0',
                                            style: theme.textTheme.bodyMedium
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
                                        _buildPolicyPoint(
                                          context,
                                          Icons.code,
                                          'Open Source',
                                          'This application is built with Flutter and utilizes various open-source libraries. We believe in transparency and community-driven development.',
                                        ),
                                        _buildPolicyPoint(
                                          context,
                                          Icons.favorite,
                                          'Mission',
                                          'Designed to help organizations and groups track participation with ease, respecting user privacy and providing local-first reliability.',
                                        ),
                                        const SizedBox(height: 24),
                                        Center(
                                          child: OutlinedButton(
                                            onPressed: () => showLicensePage(
                                              context: context,
                                              applicationName:
                                                  'Attendance Tracker',
                                              applicationVersion: '2.4.0',
                                            ),
                                            child: const Text('View Licenses'),
                                          ),
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
