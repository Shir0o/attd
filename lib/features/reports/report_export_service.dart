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
import 'report_models.dart';

class ReportExportService {
  ReportExportService({
    required this.sessionRepository,
    DateTime Function()? clock,
    Future<Directory> Function()? directoryProvider,
  }) : _clock = clock ?? DateTime.now,
       _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final SessionRepository sessionRepository;
  final DateTime Function() _clock;
  final Future<Directory> Function() _directoryProvider;

  bool get supportsGoogleSheets => !kIsWeb;

  Future<ReportExportResult> exportReport(ReportRequest request) async {
    final sessions = await sessionRepository.loadSessions();
    final filteredSessions =
        sessions
            .where(
              (session) =>
                  !session.sessionDate.isBefore(request.startDate) &&
                  !session.sessionDate.isAfter(request.endDate),
            )
            .toList()
          ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));

    final summary = _summarize(filteredSessions);

    final bytes = switch (request.format) {
      ReportFormat.csv => _renderCsv(filteredSessions),
      ReportFormat.pdf => _renderPdf(filteredSessions, summary),
      ReportFormat.image => _renderImage(filteredSessions, summary),
    };

    final filePath = await _writeFile(bytes, request.format);
    final syncedToSheets = request.syncToGoogleSheets && supportsGoogleSheets;

    return ReportExportResult(
      filePath: filePath,
      format: request.format,
      summary: summary,
      syncedToSheets: syncedToSheets,
    );
  }

  ReportSummary _summarize(List<Session> sessions) {
    var present = 0;
    var partial = 0;
    var absent = 0;
    var records = 0;

    for (final session in sessions) {
      for (final record in session.records) {
        records++;
        switch (record.status) {
          case AttendanceStatus.present:
            present++;
            break;
          case AttendanceStatus.partial:
            present++;
            partial++;
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
      partial: partial,
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
    final buffer = StringBuffer()
      ..writeln('Attendance summary report')
      ..writeln('Generated at: ${_clock().toIso8601String()}')
      ..writeln(
        'Sessions: ${summary.sessionCount}, records: ${summary.recordCount}',
      )
      ..writeln(
        'Present: ${summary.present}, Partial: ${summary.partial}, Absent: ${summary.absent}',
      )
      ..writeln('---');

    for (final session in sessions) {
      buffer.writeln(
        '• ${session.title} (${session.sessionDate.toIso8601String()})',
      );
      for (final record in session.records) {
        buffer.writeln('  - ${record.attendee}: ${record.status.name}');
      }
    }

    return Uint8List.fromList(utf8.encode(buffer.toString()));
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
      'Partial: ${summary.partial}',
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

  Future<String> _writeFile(
    Future<Uint8List> bytesFuture,
    ReportFormat format,
  ) async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);

    final now = _clock();
    final filename =
        'attendance_report_${now.millisecondsSinceEpoch}.${_extensionFor(format)}';
    final filePath = p.join(directory.path, filename);
    final file = File(filePath);
    final bytes = await bytesFuture;
    await file.writeAsBytes(bytes, flush: true);
    return filePath;
  }

  String _escape(String value) => value.replaceAll('"', '\\"');

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
