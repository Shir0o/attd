import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum ReportFormat { csv, pdf, image }

class ReportRequest {
  ReportRequest({
    required this.startDate,
    required this.endDate,
    required this.format,
    this.syncToGoogleSheets = false,
    this.includeWatchlist = true,
  }) : assert(
         !endDate.isBefore(startDate),
         'End date must be after start date',
       );

  final DateTime startDate;
  final DateTime endDate;
  final ReportFormat format;
  final bool syncToGoogleSheets;
  final bool includeWatchlist;

  ReportRequest copyWith({
    DateTime? startDate,
    DateTime? endDate,
    ReportFormat? format,
    bool? syncToGoogleSheets,
    bool? includeWatchlist,
  }) {
    return ReportRequest(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      format: format ?? this.format,
      syncToGoogleSheets: syncToGoogleSheets ?? this.syncToGoogleSheets,
      includeWatchlist: includeWatchlist ?? this.includeWatchlist,
    );
  }
}

class ReportSummary {
  const ReportSummary({
    required this.sessionCount,
    required this.recordCount,
    required this.present,
    required this.partial,
    required this.absent,
  });

  final int sessionCount;
  final int recordCount;
  final int present;
  final int partial;
  final int absent;

  double get attendanceRate =>
      recordCount == 0 ? 0 : present / recordCount * 100;
}

class ReportExportResult {
  const ReportExportResult({
    required this.filePath,
    required this.format,
    required this.summary,
    required this.syncedToSheets,
  });

  final String filePath;
  final ReportFormat format;
  final ReportSummary summary;
  final bool syncedToSheets;
}

class ReportShareOption {
  const ReportShareOption({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final AsyncCallback onTap;
}
