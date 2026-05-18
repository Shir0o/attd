import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/session_repository.dart';
import 'report_export_service.dart';
import 'report_models.dart';

class ReportExportPage extends StatefulWidget {
  const ReportExportPage({
    super.key,
    required this.sessionRepository,
    this.exportService,
  });

  final SessionRepository sessionRepository;
  final ReportExportService? exportService;

  @override
  State<ReportExportPage> createState() => _ReportExportPageState();
}

class _ReportExportPageState extends State<ReportExportPage> {
  late final ReportExportService _exportService;
  late DateTimeRange _range;
  ReportFormat _format = ReportFormat.csv;
  bool _syncSheets = false;
  ReportExportResult? _lastResult;
  bool _isProcessing = false;
  String? _error;
  String? _statusMessage;

  List<String> _availableEventTitles = [];
  final Set<String> _selectedEventTitles = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
    _exportService = widget.exportService ??
        ReportExportService(sessionRepository: widget.sessionRepository);
    _syncSheets = _exportService.supportsGoogleSheets;
    _loadEventTitles();
  }

  Future<void> _loadEventTitles() async {
    try {
      final sessions = await widget.sessionRepository.loadSessions();
      final titles = sessions.map((s) => s.title).toSet().toList()..sort();
      if (mounted) {
        setState(() {
          _availableEventTitles = titles;
        });
      }
    } catch (e) {
      // Ignore title loading errors for now
    }
  }

  Future<void> _pickRange() async {
    final selection = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (selection != null) {
      setState(() => _range = selection);
    }
  }

  Future<void> _export() async {
    setState(() {
      _isProcessing = true;
      _error = null;
      _statusMessage = _syncSheets ? 'Uploading to Sheets…' : null;
    });

    try {
      final result = await _exportService.exportReport(
        ReportRequest(
          startDate: _range.start,
          endDate: _range.end,
          format: _format,
          syncToGoogleSheets: _syncSheets,
          selectedEventTitles: _selectedEventTitles.toList(),
        ),
      );
      setState(() {
        _lastResult = result;
        _statusMessage =
            result.sheetSync?.success == true
                ? 'Uploaded to Sheets'
                : result.sheetSync?.error ?? _statusMessage;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${result.format.name.toUpperCase()} to ${result.filePath}',
          ),
        ),
      );
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _shareResult() async {
    final path = _lastResult?.filePath;
    if (path == null) return;

    final file = XFile(path);
    await Share.shareXFiles(
      [file],
      text: 'Attendance Report (${_lastResult!.format.name.toUpperCase()})',
    );
  }

  Future<void> _copyPath() async {
    final path = _lastResult?.filePath;
    if (path == null) return;
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File path copied to clipboard')),
    );
  }

  Future<void> _saveCopyToDownloads() async {
    final path = _lastResult?.filePath;
    if (path == null) return;
    final source = File(path);
    if (!await source.exists()) return;
    final downloads = Directory.systemTemp.createTempSync('report_export');
    final destination = File(
      '${downloads.path}/${source.uri.pathSegments.last}',
    );
    await destination.writeAsBytes(await source.readAsBytes(), flush: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Secondary copy saved to ${destination.path}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final supportsSheets = _exportService.supportsGoogleSheets;

    return Scaffold(
      appBar: AppBar(title: const Text('Export reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Reporting Window Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reporting window', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Start', style: theme.textTheme.labelMedium),
                          Text(
                            '${_range.start.year}-${_range.start.month.toString().padLeft(2, '0')}-${_range.start.day.toString().padLeft(2, '0')}',
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('End', style: theme.textTheme.labelMedium),
                          Text(
                            '${_range.end.year}-${_range.end.month.toString().padLeft(2, '0')}-${_range.end.day.toString().padLeft(2, '0')}',
                          ),
                        ],
                      ),
                      FilledButton.icon(
                        onPressed: _pickRange,
                        icon: const Icon(Icons.date_range_outlined),
                        label: const Text('Change'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Event Selection Card
          if (_availableEventTitles.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Events', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Leave unselected to include all events in the date range.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children:
                          _availableEventTitles.map((title) {
                            final isSelected = _selectedEventTitles.contains(
                              title,
                            );
                            return FilterChip(
                              label: Text(title),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedEventTitles.add(title);
                                  } else {
                                    _selectedEventTitles.remove(title);
                                  }
                                });
                              },
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Output format', style: theme.textTheme.titleMedium),
                      DropdownButton<ReportFormat>(
                        value: _format,
                        items:
                            ReportFormat.values
                                .map(
                                  (format) => DropdownMenuItem(
                                    value: format,
                                    child: Text(format.name.toUpperCase()),
                                  ),
                                )
                                .toList(),
                        onChanged: (format) {
                          if (format == null) return;
                          setState(() => _format = format);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'CSV exports the raw check-ins. PDF and image options render a shareable attendance summary.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sync to Google Sheets'),
                    subtitle: Text(
                      supportsSheets
                          ? 'Push a copy to your shared spreadsheet when available.'
                          : 'Sheets sync is disabled for this build target.',
                    ),
                    value: _syncSheets,
                    onChanged:
                        supportsSheets
                            ? (value) => setState(() => _syncSheets = value)
                            : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  if (_isProcessing)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          FilledButton.icon(
            onPressed: _isProcessing ? null : _export,
            icon:
                _isProcessing
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.description),
            label: Text(
              _isProcessing ? 'Preparing report…' : 'Generate report',
            ),
          ),
          const SizedBox(height: 12),
          if (_lastResult != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Last export', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(_lastResult!.filePath, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _shareResult,
                        icon: const Icon(Icons.share),
                        label: const Text('Share Report'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.secondaryContainer,
                          foregroundColor: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy Path'),
                          onPressed: _copyPath,
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.save_alt_outlined, size: 16),
                          label: const Text('Local Copy'),
                          onPressed: _saveCopyToDownloads,
                        ),
                        if (_lastResult!.sheetSync?.success == true)
                          const Chip(
                            avatar: Icon(Icons.cloud_done_outlined, size: 16),
                            label: Text('Synced'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sessions: ${_lastResult!.summary.sessionCount}, records: ${_lastResult!.summary.recordCount}, attendance rate: ${_lastResult!.summary.attendanceRate.toStringAsFixed(1)}%',
                    ),
                    if (_lastResult!.sheetSync?.shareLink != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Last synced sheet:',
                        style: theme.textTheme.labelMedium,
                      ),
                      InkWell(
                        onTap:
                            () => Clipboard.setData(
                              ClipboardData(
                                text: _lastResult!.sheetSync!.shareLink!,
                              ),
                            ),
                        child: Text(
                          _lastResult!.sheetSync!.shareLink!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
