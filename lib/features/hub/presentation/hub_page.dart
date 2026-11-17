import 'package:flutter/material.dart';
import '../../../../data/session_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../../core/crashlytics/crash_reporting_service.dart';
import '../../settings/application/app_lock_controller.dart';
import '../../settings/application/theme_controller.dart';
import '../../settings/data/drive_service.dart';
import '../../settings/data/local_backup_service.dart';
import '../../reminders/application/attendance_reminder_service.dart';
import '../../reminders/application/reminder_settings_controller.dart';
import '../../handoff/data/handoff_sharer.dart';
import '../../handoff/data/incoming_handoff_files.dart';
import '../../handoff/presentation/handoff_intake.dart';
import '../data/event_repository.dart';
import 'hub_attendance_view.dart';

class HubPage extends StatefulWidget {
  const HubPage({
    super.key,
    required this.sessionRepository,
    required this.eventRepository,
    required this.attendanceRepository,
    required this.themeController,
    this.driveService,
    this.localBackupService,
    this.handoffSharer,
    this.handoffIntake,
    this.pickHandoffBytes,
    this.appLockController,
    this.crashReportingService,
    this.reminderSettingsController,
    this.reminderService,
    this.disableAnimations = false,
  });

  final SessionRepository sessionRepository;
  final EventRepository eventRepository;
  final AttendanceRepository attendanceRepository;
  final ThemeController themeController;
  final DriveService? driveService;
  final LocalBackupService? localBackupService;
  final HandoffSharer? handoffSharer;
  final HandoffIntake? handoffIntake;
  final PickHandoffBytes? pickHandoffBytes;
  final AppLockController? appLockController;
  final CrashReportingService? crashReportingService;
  final ReminderSettingsController? reminderSettingsController;
  final AttendanceReminderService? reminderService;
  final bool disableAnimations;

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
      driveService: widget.driveService,
      localBackupService: widget.localBackupService,
      handoffSharer: widget.handoffSharer,
      handoffIntake: widget.handoffIntake,
      pickHandoffBytes: widget.pickHandoffBytes,
      appLockController: widget.appLockController,
      crashReportingService: widget.crashReportingService,
      reminderSettingsController: widget.reminderSettingsController,
      reminderService: widget.reminderService,
      disableAnimations: widget.disableAnimations,
    );
  }
}
