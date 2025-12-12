import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'report_models.dart';

abstract class SheetsClient {
  Future<SheetSyncResult> uploadReport({
    required Uint8List bytes,
    required ReportFormat format,
    required DateTime generatedAt,
    String? suggestedFileName,
  });
}

class LocalSheetsClient implements SheetsClient {
  LocalSheetsClient(this._directoryProvider);

  final Future<Directory> Function() _directoryProvider;

  @override
  Future<SheetSyncResult> uploadReport({
    required Uint8List bytes,
    required ReportFormat format,
    required DateTime generatedAt,
    String? suggestedFileName,
  }) async {
    final directory = await _directoryProvider();
    final sheetsDir = Directory(p.join(directory.path, 'sheets_sync'));
    await sheetsDir.create(recursive: true);

    final fileName =
        suggestedFileName ??
        'sheets_report_${generatedAt.millisecondsSinceEpoch}.${format.name}';
    final file = File(p.join(sheetsDir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    return SheetSyncResult(
      attempted: true,
      success: true,
      shareLink: file.uri.toString(),
    );
  }
}
