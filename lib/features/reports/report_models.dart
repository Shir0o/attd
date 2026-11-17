import '../hub/domain/event.dart';

enum ReportFormat { csv }

class ReportRequest {
  ReportRequest({
    required this.startDate,
    required this.endDate,
    required this.format,
    this.event,
  }) : assert(
         !endDate.isBefore(startDate),
         'End date must be after start date',
       );

  final DateTime startDate;
  final DateTime endDate;
  final ReportFormat format;

  /// When set, only this event's sessions are exported.
  final Event? event;

  ReportRequest copyWith({
    DateTime? startDate,
    DateTime? endDate,
    ReportFormat? format,
    Event? event,
  }) {
    return ReportRequest(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      format: format ?? this.format,
      event: event ?? this.event,
    );
  }
}

class ReportSummary {
  const ReportSummary({
    required this.sessionCount,
    required this.recordCount,
    required this.present,
    required this.absent,
    this.lateCount = 0,
  });

  final int sessionCount;
  final int recordCount;
  final int present;
  final int absent;

  /// How many records are present-but-late. A late record still counts as a
  /// full present — this is a footnote on [present], not a third status.
  final int lateCount;

  double get attendanceRate =>
      recordCount == 0 ? 0 : present / recordCount * 100;
}

class ReportExportResult {
  const ReportExportResult({
    required this.filePath,
    required this.format,
    required this.summary,
  });

  final String filePath;
  final ReportFormat format;
  final ReportSummary summary;
}
