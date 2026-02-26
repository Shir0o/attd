import 'package:flutter/material.dart';
import '../../../../data/session_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../settings/application/theme_controller.dart';
import '../../settings/data/drive_service.dart';
import '../../settings/data/local_backup_service.dart';
import '../data/event_repository.dart';
import 'hub_attendance_view.dart';

class HubPage extends StatefulWidget {
  const HubPage({
    super.key,
    required this.sessionRepository,
    required this.eventRepository,
    required this.attendanceRepository,
    required this.themeController,
    this.onSignOut,
    this.driveService,
    this.localBackupService,
  });

  final SessionRepository sessionRepository;
  final EventRepository eventRepository;
  final AttendanceRepository attendanceRepository;
  final ThemeController themeController;
  final VoidCallback? onSignOut;
  final DriveService? driveService;
  final LocalBackupService? localBackupService;

  @override
  State<HubPage> createState() => _HubPageState();
}

class _HubPageState extends State<HubPage> {
  @override
  Widget build(BuildContext context) {
    return HubAttendanceView(
      sessionRepository: widget.sessionRepository,
      eventRepository: widget.eventRepository,
      attendanceRepository: widget.attendanceRepository,
      themeController: widget.themeController,
      onSignOut: widget.onSignOut,
      driveService: widget.driveService,
      localBackupService: widget.localBackupService,
    );
  }
}
