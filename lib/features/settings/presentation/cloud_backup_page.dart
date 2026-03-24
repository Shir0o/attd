import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/drive_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class CloudBackupPage extends StatefulWidget {
  const CloudBackupPage({super.key, required this.driveService});

  final DriveService driveService;

  @override
  State<CloudBackupPage> createState() => _CloudBackupPageState();
}

class _CloudBackupPageState extends State<CloudBackupPage> {
  late Future<List<drive.File>> _backupsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _backupsFuture = widget.driveService.listCloudBackups();
    });
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
        await widget.driveService.restoreFromBackup(backup.id!);
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
        title: const Text('Cloud Version History'),
        backgroundColor: colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<drive.File>>(
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
                    Icons.cloud_off_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text('No cloud backups found'),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: backups.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final backup = backups[index];
              final dateStr = DateFormat('EEEE, MMM d, yyyy').format(backup.createdTime!);
              final timeStr = DateFormat('HH:mm').format(backup.createdTime!);
              final size = (int.parse(backup.size ?? '0') / 1024).toStringAsFixed(1);

              return Card(
                elevation: 0,
                color: colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(Icons.cloud_download, color: colorScheme.onPrimaryContainer),
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
}
