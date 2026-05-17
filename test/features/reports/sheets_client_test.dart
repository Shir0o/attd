import 'dart:io';
import 'dart:typed_data';

import 'package:attendance_tracker/features/reports/report_models.dart';
import 'package:attendance_tracker/features/reports/sheets_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalSheetsClient', () {
    late Directory tempDir;

    setUp(() async {
      tempDir =
          await Directory.systemTemp.createTemp('local_sheets_client_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes report bytes to sheets_sync with suggested file name',
        () async {
      final client = LocalSheetsClient(() async => tempDir);
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      final result = await client.uploadReport(
        bytes: bytes,
        format: ReportFormat.csv,
        generatedAt: DateTime(2026, 5, 17, 10),
        suggestedFileName: 'attendance.csv',
      );

      final output = File('${tempDir.path}/sheets_sync/attendance.csv');
      expect(await output.readAsBytes(), bytes);
      expect(result.attempted, isTrue);
      expect(result.success, isTrue);
      expect(result.shareLink, output.uri.toString());
    });

    test('uses generated file name when no suggestion is provided', () async {
      final client = LocalSheetsClient(() async => tempDir);
      final generatedAt = DateTime.fromMillisecondsSinceEpoch(123456);

      final result = await client.uploadReport(
        bytes: Uint8List.fromList([5]),
        format: ReportFormat.pdf,
        generatedAt: generatedAt,
      );

      final output =
          File('${tempDir.path}/sheets_sync/sheets_report_123456.pdf');
      expect(await output.exists(), isTrue);
      expect(result.shareLink, output.uri.toString());
    });
  });
}
