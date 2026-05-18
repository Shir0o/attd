import 'package:attendance_tracker/features/reports/report_models.dart';
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
}
