import 'package:attendance_tracker/features/reports/report_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportRequest', () {
    test('copyWith preserves existing values and overrides selected fields',
        () {
      final request = ReportRequest(
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 17),
        format: ReportFormat.csv,
        selectedEventTitles: const ['Sunday'],
      );

      final updated = request.copyWith(
        format: ReportFormat.pdf,
        syncToGoogleSheets: true,
        includeWatchlist: false,
      );

      expect(updated.startDate, request.startDate);
      expect(updated.endDate, request.endDate);
      expect(updated.format, ReportFormat.pdf);
      expect(updated.syncToGoogleSheets, isTrue);
      expect(updated.includeWatchlist, isFalse);
      expect(updated.selectedEventTitles, ['Sunday']);
    });

    test('copyWith keeps all values when no overrides are provided', () {
      final request = ReportRequest(
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 17),
        format: ReportFormat.image,
        syncToGoogleSheets: true,
        includeWatchlist: false,
        selectedEventTitles: const ['Sunday'],
      );

      final updated = request.copyWith();

      expect(updated.startDate, request.startDate);
      expect(updated.endDate, request.endDate);
      expect(updated.format, request.format);
      expect(updated.syncToGoogleSheets, request.syncToGoogleSheets);
      expect(updated.includeWatchlist, request.includeWatchlist);
      expect(updated.selectedEventTitles, request.selectedEventTitles);
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

  group('report result models', () {
    test('store constructor values', () async {
      final summary = const ReportSummary(
        sessionCount: 2,
        recordCount: 5,
        present: 4,
        absent: 1,
      );
      final sheetSync = const SheetSyncResult(
        attempted: true,
        success: false,
        shareLink: 'https://sheet.test/report',
        error: 'denied',
      );
      final export = ReportExportResult(
        filePath: '/tmp/report.csv',
        format: ReportFormat.csv,
        summary: summary,
        sheetSync: sheetSync,
      );

      var tapped = false;
      final shareOption = ReportShareOption(
        label: 'Share',
        icon: Icons.share,
        onTap: () async {
          tapped = true;
        },
      );
      await shareOption.onTap();

      expect(export.filePath, '/tmp/report.csv');
      expect(export.format, ReportFormat.csv);
      expect(export.summary, summary);
      expect(export.sheetSync, sheetSync);
      expect(sheetSync.attempted, isTrue);
      expect(sheetSync.success, isFalse);
      expect(sheetSync.shareLink, 'https://sheet.test/report');
      expect(sheetSync.error, 'denied');
      expect(shareOption.label, 'Share');
      expect(shareOption.icon, Icons.share);
      expect(tapped, isTrue);
    });
  });
}
