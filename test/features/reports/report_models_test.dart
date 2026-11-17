import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/reports/report_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportRequest', () {
    final event = Event(
      id: 'e1',
      title: 'Sunday',
      time: const TimeOfDay(hour: 10, minute: 0),
      frequency: 'Weekly',
      createdAt: DateTime(2026, 1, 1),
    );

    test('copyWith overrides selected fields and keeps the rest', () {
      final request = ReportRequest(
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 17),
        format: ReportFormat.csv,
        event: event,
      );

      final updated = request.copyWith(endDate: DateTime(2026, 5, 20));

      expect(updated.startDate, request.startDate);
      expect(updated.endDate, DateTime(2026, 5, 20));
      expect(updated.format, ReportFormat.csv);
      expect(updated.event, event);
    });

    test('copyWith keeps all values when no overrides are provided', () {
      final request = ReportRequest(
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 17),
        format: ReportFormat.csv,
        event: event,
      );

      final updated = request.copyWith();

      expect(updated.startDate, request.startDate);
      expect(updated.endDate, request.endDate);
      expect(updated.format, request.format);
      expect(updated.event, request.event);
    });

    test('rejects an end date before the start date', () {
      expect(
        () => ReportRequest(
          startDate: DateTime(2026, 5, 17),
          endDate: DateTime(2026, 5, 1),
          format: ReportFormat.csv,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('ReportSummary', () {
    test('calculates attendance rate and handles empty reports', () {
      expect(
        const ReportSummary(
          sessionCount: 1,
          recordCount: 4,
          present: 3,
          absent: 1,
        ).attendanceRate,
        75,
      );
      expect(
        const ReportSummary(
          sessionCount: 0,
          recordCount: 0,
          present: 0,
          absent: 0,
        ).attendanceRate,
        0,
      );
    });
  });

  test('ReportExportResult stores constructor values', () {
    const summary = ReportSummary(
      sessionCount: 2,
      recordCount: 5,
      present: 4,
      absent: 1,
    );
    const export = ReportExportResult(
      filePath: '/tmp/report.csv',
      format: ReportFormat.csv,
      summary: summary,
    );

    expect(export.filePath, '/tmp/report.csv');
    expect(export.format, ReportFormat.csv);
    expect(export.summary, summary);
  });
}
