import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/session.dart';
import '../../data/session_repository.dart';
import '../attendance/models/attendance_status.dart';
import '../hub/domain/event.dart';
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

  Future<ReportExportResult> exportReport(ReportRequest request) async {
    final sessions = await sessionRepository.loadSessions();
    final event = request.event;
    final filteredSessions =
        sessions.where((session) {
          final inDateRange =
              !session.sessionDate.isBefore(request.startDate) &&
              !session.sessionDate.isAfter(request.endDate);
          if (!inDateRange) return false;

          // Same rule the History page uses to list an event's sessions.
          return event == null || event.owns(session);
        }).toList()
          ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));

    final summary = _summarize(filteredSessions);
    final bytes = await _renderCsv(filteredSessions);
    final filePath = await _writeFile(bytes);

    return ReportExportResult(
      filePath: filePath,
      format: request.format,
      summary: summary,
    );
  }

  ReportSummary _summarize(List<Session> sessions) {
    var present = 0;
    var absent = 0;
    var late = 0;
    var records = 0;

    for (final session in sessions) {
      for (final record in session.records) {
        records++;
        switch (record.status) {
          case AttendanceStatus.present:
            present++;
            if (record.isLate) late++;
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
      lateCount: late,
    );
  }

  Future<Uint8List> _renderCsv(List<Session> sessions) async {
    final buffer = StringBuffer()
      ..writeln('Session Date,Title,Attendee,Status,Late');
    for (final session in sessions) {
      for (final record in session.records) {
        buffer.writeln(
          '${session.sessionDate.toIso8601String()},'
          '"${_escape(session.title)}",'
          '"${_escape(record.attendee)}",'
          '${record.status.name},'
          '${record.isLate}',
        );
      }
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  Future<String> _writeFile(Uint8List bytes) async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);

    final now = _clock();
    final filename = 'attendance_report_${now.millisecondsSinceEpoch}.csv';
    final filePath = p.join(directory.path, filename);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return filePath;
  }

  String _escape(String value) => value.replaceAll('"', '\\"');
}
