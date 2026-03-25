import 'dart:convert';
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) {
      return 'Today';
    } else if (targetDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('History & Restore', style: TextStyle(fontWeight: FontWeight.normal)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                    Icons.history,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text('No cloud history found'),
                ],
              ),
            );
          }

          return Stack(
            children: [
              // Vertical line
              Positioned(
                left: 26, // 16 padding + 11 radius - 1 (half line width)
                top: 32,
                bottom: 40,
                child: Container(
                  width: 2,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              ListView.builder(
                padding: const EdgeInsets.only(top: 16, bottom: 40, left: 16, right: 16),
                itemCount: backups.length + 1, // +1 for "End of history"
                itemBuilder: (context, index) {
                  if (index == backups.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 8),
                      child: Center(
                        child: Text(
                          'End of history',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }

                  final backup = backups[index];
                  final isFirst = index == 0;
                  final createdTime = backup.createdTime!;
                  final timeStr = DateFormat('hh:mm a').format(createdTime);
                  final dateStr = _formatDate(createdTime);

                  // Parse properties or description for metadata
                  String title = 'Snapshot';
                  String user = 'System';
                  List<Widget> tags = [];
                  bool isInitialSetup = false;
                  String? italicDescription;

                  if (backup.description != null && backup.description!.isNotEmpty) {
                    try {
                      final metadata = jsonDecode(backup.description!);
                      title = metadata['title'] ?? title;
                      user = metadata['user'] ?? user;
                      if (metadata['tags'] != null && metadata['tags'] is List) {
                        for (final tag in metadata['tags']) {
                          final text = tag.toString();
                          final isPositive = text.startsWith('+');
                          final isNegative = text.startsWith('-');

                          Color bgColor = colorScheme.surfaceContainerHighest;
                          Color textColor = colorScheme.onSurfaceVariant;

                          if (isPositive) {
                            bgColor = Colors.green.shade100;
                            textColor = Colors.green.shade800;
                          } else if (isNegative) {
                            bgColor = Colors.red.shade100;
                            textColor = Colors.red.shade800;
                          }

                          tags.add(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                text,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                              ),
                            )
                          );
                        }
                      }

                      if (metadata['isInitialSetup'] == true) {
                        isInitialSetup = true;
                        italicDescription = metadata['description'] ?? 'Repository initialized';
                      }
                    } catch (e) {
                      // fallback to size
                      final size = (int.parse(backup.size ?? '0') / 1024).toStringAsFixed(1);
                      italicDescription = '$size KB';
                    }
                  } else {
                    final size = (int.parse(backup.size ?? '0') / 1024).toStringAsFixed(1);
                    italicDescription = '$size KB';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timeline Dot
                        Container(
                          margin: const EdgeInsets.only(top: 24, right: 16),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.surface,
                            border: Border.all(
                              color: isFirst ? colorScheme.primary : colorScheme.outlineVariant,
                              width: 2,
                            ),
                          ),
                          child: isFirst ? Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.primary,
                              ),
                            ),
                          ) : null,
                        ),

                        // Card
                        Expanded(
                          child: Opacity(
                            opacity: isInitialSetup ? 0.75 : 1.0,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  '$dateStr, $timeStr',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isFirst ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                                    fontWeight: isFirst ? FontWeight.w500 : FontWeight.normal,
                                                  ),
                                                ),
                                                Text(
                                                  ' • ',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                                Text(
                                                  user,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isInitialSetup)
                                        IconButton(
                                          icon: const Icon(Icons.more_vert),
                                          iconSize: 20,
                                          color: colorScheme.onSurfaceVariant,
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {},
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  if (tags.isNotEmpty)
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: tags,
                                    )
                                  else if (italicDescription != null)
                                    Text(
                                      italicDescription,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),

                                  const SizedBox(height: 16),

                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      onPressed: isInitialSetup ? null : () => _restore(backup),
                                      icon: const Icon(Icons.history, size: 18),
                                      label: const Text('Restore'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: colorScheme.primary,
                                        side: BorderSide(
                                          color: isInitialSetup
                                              ? colorScheme.outline.withValues(alpha: 0.3)
                                              : colorScheme.outline,
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
