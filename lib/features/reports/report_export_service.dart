import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/session.dart';
import '../../data/session_repository.dart';
import '../attendance/models/attendance_status.dart';
import 'sheets_client.dart';
import 'report_models.dart';

class ReportExportService {
  ReportExportService({
    required this.sessionRepository,
    DateTime Function()? clock,
    Future<Directory> Function()? directoryProvider,
    SheetsClient? sheetsClient,
  }) : _clock = clock ?? DateTime.now,
       _directoryProvider = directoryProvider ?? getApplicationSupportDirectory,
       sheetsClient =
           sheetsClient ??
           (!kIsWeb
               ? LocalSheetsClient(
                   directoryProvider ?? getApplicationSupportDirectory,
                 )
               : null);

  final SessionRepository sessionRepository;
  final DateTime Function() _clock;
  final Future<Directory> Function() _directoryProvider;
  final SheetsClient? sheetsClient;

  bool get supportsGoogleSheets => !kIsWeb && sheetsClient != null;

  Future<ReportExportResult> exportReport(ReportRequest request) async {
    final sessions = await sessionRepository.loadSessions();
    final filteredSessions =
        sessions.where((session) {
          final inDateRange =
              !session.sessionDate.isBefore(request.startDate) &&
              !session.sessionDate.isAfter(request.endDate);
          if (!inDateRange) return false;

          if (request.selectedEventTitles.isNotEmpty) {
            return request.selectedEventTitles.contains(session.title);
          }
          return true;
        }).toList()
          ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));

    final summary = _summarize(filteredSessions);

    final bytes = await switch (request.format) {
      ReportFormat.csv => _renderCsv(filteredSessions),
      ReportFormat.pdf => _renderPdf(filteredSessions, summary),
      ReportFormat.image => _renderImage(filteredSessions, summary),
    };

    final filePath = await _writeFile(bytes, request.format);
    final sheetSync = await _maybeUploadToSheets(
      request,
      bytes,
      generatedAt: _clock(),
      suggestedFileName: p.basename(filePath),
    );

    return ReportExportResult(
      filePath: filePath,
      format: request.format,
      summary: summary,
      sheetSync: sheetSync,
    );
  }

  Future<SheetSyncResult?> _maybeUploadToSheets(
    ReportRequest request,
    Uint8List bytes, {
    required DateTime generatedAt,
    String? suggestedFileName,
  }) async {
    if (!request.syncToGoogleSheets) {
      return null;
    }

    if (!supportsGoogleSheets || sheetsClient == null) {
      return const SheetSyncResult(
        attempted: false,
        success: false,
        error: 'Sheets sync is not supported on this platform.',
      );
    }

    try {
      return await sheetsClient!.uploadReport(
        bytes: bytes,
        format: request.format,
        generatedAt: generatedAt,
        suggestedFileName: suggestedFileName,
      );
    } catch (error) {
      return SheetSyncResult(
        attempted: true,
        success: false,
        error: error.toString(),
      );
    }
  }

  ReportSummary _summarize(List<Session> sessions) {
    var present = 0;
    var absent = 0;
    var records = 0;

    for (final session in sessions) {
      for (final record in session.records) {
        records++;
        switch (record.status) {
          case AttendanceStatus.present:
            present++;
            break;
          case AttendanceStatus.absent:
            absent++;
            break;
        }
      }
    }

    return ReportSummary(
      sessionCount: sessions.length,
      recordCount: records,
      present: present,
      absent: absent,
    );
  }

  Future<Uint8List> _renderCsv(List<Session> sessions) async {
    final buffer = StringBuffer()
      ..writeln('Session Date,Title,Attendee,Status');
    for (final session in sessions) {
      for (final record in session.records) {
        buffer.writeln(
          '${session.sessionDate.toIso8601String()},'
          '"${_escape(session.title)}",'
          '"${_escape(record.attendee)}",'
          '${record.status.name}',
        );
      }
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  Future<Uint8List> _renderPdf(
    List<Session> sessions,
    ReportSummary summary,
  ) async {
    final lines = <String>[
      'Attendance summary report',
      'Generated at: ${_clock().toIso8601String()}',
      'Sessions: ${summary.sessionCount}, records: ${summary.recordCount}',
      'Present: ${summary.present}, Absent: ${summary.absent}',
      '---',
    ];

    for (final session in sessions) {
      lines.add('${session.title} (${session.sessionDate.toIso8601String()})');
      for (final record in session.records) {
        lines.add('  - ${record.attendee}: ${record.status.name}');
      }
    }

    return _buildPdfDocument(lines);
  }

  Uint8List _buildPdfDocument(List<String> lines) {
    final content = StringBuffer()
      ..writeln('BT')
      ..writeln('/F1 12 Tf')
      ..writeln('14 TL')
      ..writeln('72 720 Td');

    for (final line in lines) {
      content.writeln('(${_pdfEscape(line)}) Tj');
      content.writeln('T*');
    }

    content.writeln('ET');

    final contentBytes = utf8.encode(content.toString());

    final objects = <String>[
      '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj',
      '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj',
      '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>\nendobj',
      '4 0 obj\n<< /Length ${contentBytes.length} >>\nstream\n${utf8.decode(contentBytes)}\nendstream\nendobj',
      '5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj',
    ];

    final buffer = BytesBuilder();
    buffer.add(utf8.encode('%PDF-1.4\n'));

    final offsets = <int>[];
    for (final object in objects) {
      offsets.add(buffer.length);
      buffer.add(utf8.encode('$object\n'));
    }

    final xrefOffset = buffer.length;
    final count = objects.length + 1;
    final xref = StringBuffer()
      ..writeln('xref')
      ..writeln('0 $count')
      ..writeln('0000000000 65535 f ');

    for (final offset in offsets) {
      xref.writeln('${offset.toString().padLeft(10, '0')} 00000 n ');
    }

    xref
      ..writeln('trailer')
      ..writeln('<< /Size $count /Root 1 0 R >>')
      ..writeln('startxref')
      ..writeln(xrefOffset)
      ..writeln('%%EOF');

    buffer.add(utf8.encode(xref.toString()));
    return buffer.toBytes();
  }

  Future<Uint8List> _renderImage(
    List<Session> sessions,
    ReportSummary summary,
  ) async {
    const width = 720.0;
    const height = 480.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      const ui.Rect.fromLTWH(0, 0, width, height),
    );
    canvas.drawPaint(ui.Paint()..color = const ui.Color(0xFFF3F4F6));

    final lines = <String>[
      'Attendance snapshot',
      'Sessions: ${summary.sessionCount}',
      'Records: ${summary.recordCount}',
      'Present: ${summary.present}',
      'Absent: ${summary.absent}',
      'First session: ${sessions.isNotEmpty ? sessions.first.title : 'N/A'}',
    ];

    double dy = 32;
    for (final line in lines) {
      final paragraph = _buildParagraph(line, 20);
      canvas.drawParagraph(paragraph, ui.Offset(24, dy));
      dy += paragraph.height + 8;
    }

    if (sessions.isNotEmpty) {
      final paragraph = _buildParagraph(
        'Coverage: ${sessions.first.sessionDate.toIso8601String()} - ${sessions.last.sessionDate.toIso8601String()}',
        14,
      );
      canvas.drawParagraph(paragraph, ui.Offset(24, dy));
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<String> _writeFile(Uint8List bytes, ReportFormat format) async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);

    final now = _clock();
    final filename =
        'attendance_report_${now.millisecondsSinceEpoch}.${_extensionFor(format)}';
    final filePath = p.join(directory.path, filename);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return filePath;
  }

  String _escape(String value) => value.replaceAll('"', '\\"');

  String _pdfEscape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('(', '\\(')
      .replaceAll(')', '\\)');

  String _extensionFor(ReportFormat format) {
    switch (format) {
      case ReportFormat.csv:
        return 'csv';
      case ReportFormat.pdf:
        return 'pdf';
      case ReportFormat.image:
        return 'png';
    }
  }

  ui.Paragraph _buildParagraph(String text, double fontSize) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              fontSize: fontSize,
              fontWeight: ui.FontWeight.w600,
            ),
          )
          ..pushStyle(ui.TextStyle(color: const ui.Color(0xFF111827)))
          ..addText(text);
    final paragraph = builder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 672));
    return paragraph;
  }
}
