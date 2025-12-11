import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/session_repository.dart';
import 'report_export_service.dart';
import 'report_models.dart';

class ReportExportPage extends StatefulWidget {
  const ReportExportPage({super.key, required this.sessionRepository});

  final SessionRepository sessionRepository;

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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
    _exportService = ReportExportService(
      sessionRepository: widget.sessionRepository,
    );
    _syncSheets = _exportService.supportsGoogleSheets;
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
    });

    try {
      final result = await _exportService.exportReport(
        ReportRequest(
          startDate: _range.start,
          endDate: _range.end,
          format: _format,
          syncToGoogleSheets: _syncSheets,
        ),
      );
      setState(() => _lastResult = result);
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
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File path copied. Share it with your team!'),
      ),
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
    final supportsSheets = _exportService.supportsGoogleSheets;
    return Scaffold(
      appBar: AppBar(title: const Text('Export reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reporting window',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Text(_range.start.toIso8601String()),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'End',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Text(_range.end.toIso8601String()),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Output format',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      DropdownButton<ReportFormat>(
                        value: _format,
                        items: ReportFormat.values
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
                    style: Theme.of(context).textTheme.bodyMedium,
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
                    onChanged: supportsSheets
                        ? (value) => setState(() => _syncSheets = value)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton.icon(
            onPressed: _isProcessing ? null : _export,
            icon: _isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            label: Text(
              _isProcessing ? 'Preparing report…' : 'Generate and save report',
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
                    Text(
                      'Last export',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lastResult!.filePath,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.share_outlined),
                          label: const Text('Share / copy path'),
                          onPressed: _shareResult,
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.save_alt_outlined),
                          label: const Text('Save another copy'),
                          onPressed: _saveCopyToDownloads,
                        ),
                        if (_lastResult!.syncedToSheets)
                          const Chip(
                            avatar: Icon(Icons.cloud_done_outlined),
                            label: Text('Synced to Sheets'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sessions: ${_lastResult!.summary.sessionCount}, records: ${_lastResult!.summary.recordCount}, attendance rate: ${_lastResult!.summary.attendanceRate.toStringAsFixed(1)}%',
                    ),
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
