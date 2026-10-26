import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../data/session_repository.dart';
import '../../hub/data/event_repository.dart';
import '../../hub/domain/event.dart';
import '../../hub/utils/event_date_utils.dart';
import 'reminder_settings_controller.dart';

/// Payload structure passed with an attendance reminder notification.
class AttendanceReminderPayload {
  const AttendanceReminderPayload({
    required this.eventId,
    required this.targetDateIso,
  });

  final String eventId;
  final String targetDateIso;

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'targetDateIso': targetDateIso,
      };

  String serialize() => jsonEncode(toJson());

  static AttendanceReminderPayload? deserialize(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final eventId = map['eventId'] as String?;
      final targetDateIso = map['targetDateIso'] as String?;
      if (eventId != null && targetDateIso != null) {
        return AttendanceReminderPayload(
          eventId: eventId,
          targetDateIso: targetDateIso,
        );
      }
    } catch (_) {}
    return null;
  }
}

/// Service managing local scheduled reminder notifications for taking attendance.
class AttendanceReminderService {
  AttendanceReminderService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    required ReminderSettingsController settingsController,
    required EventRepository eventRepository,
    required SessionRepository sessionRepository,
    tz.Location? localLocation,
  })  : _notifications = notificationsPlugin ?? FlutterLocalNotificationsPlugin(),
        _settingsController = settingsController,
        _eventRepository = eventRepository,
        _sessionRepository = sessionRepository,
        _localLocation = localLocation {
    _initTimezone();
  }

  final FlutterLocalNotificationsPlugin _notifications;
  final ReminderSettingsController _settingsController;
  final EventRepository _eventRepository;
  final SessionRepository _sessionRepository;
  tz.Location? _localLocation;

  static const String notificationChannelId = 'attendance_reminders';
  static const String notificationChannelName = 'Attendance Reminders';
  static const String notificationChannelDesc =
      'Reminders to take attendance for scheduled events';

  void _initTimezone() {
    try {
      tz.initializeTimeZones();
      _localLocation ??= tz.local;
    } catch (_) {}
  }

  /// Initializes the local notifications plugin.
  Future<void> initialize({
    void Function(AttendanceReminderPayload payload)? onNotificationTapped,
  }) async {
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = AttendanceReminderPayload.deserialize(response.payload);
        if (payload != null && onNotificationTapped != null) {
          onNotificationTapped(payload);
        }
      },
    );
  }

  /// Computes a stable 31-bit positive int notification ID for an event and date.
  int getNotificationId(String eventId, DateTime date) {
    final key = '$eventId-${date.year}-${date.month}-${date.day}';
    return key.hashCode.abs() & 0x7FFFFFFF;
  }

  /// Calculates the scheduled notification time for an event on a given date with an offset.
  DateTime calculateReminderTime({
    required Event event,
    required DateTime targetDate,
    required Duration offset,
  }) {
    final eventStart = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      event.time.hour,
      event.time.minute,
    );
    return eventStart.add(offset);
  }

  /// Cancels an existing notification for a specific event and session date.
  Future<void> cancelReminderForSession(String eventId, DateTime date) async {
    final id = getNotificationId(eventId, date);
    await _notifications.cancel(id: id);
  }

  /// Synchronizes and updates scheduled reminders for all upcoming events based on
  /// current settings and existing recorded sessions.
  Future<void> syncReminders({DateTime? currentTime}) async {
    final now = currentTime ?? DateTime.now();

    if (!_settingsController.enabled) {
      await _notifications.cancelAll();
      return;
    }

    final events = await _eventRepository.fetchAllEvents();
    final activeEvents = events.where((e) => e.deletedAt == null).toList();
    final allSessions = await _sessionRepository.fetchAllSessions();

    final offset = _settingsController.offset.duration;

    for (final event in activeEvents) {
      // Find the next occurrence on or after today
      final targetDate = getNextOccurrence(event, now);
      final sessionDate = DateTime(targetDate.year, targetDate.month, targetDate.day);

      // Check suppression: has attendance already been recorded for this event and date?
      final isRecorded = allSessions.any((s) {
        final matchesEvent = (s.eventId != null && s.eventId == event.id) ||
            s.title.trim().toLowerCase() == event.title.trim().toLowerCase();
        final sameDate = s.sessionDate.year == sessionDate.year &&
            s.sessionDate.month == sessionDate.month &&
            s.sessionDate.day == sessionDate.day;
        return matchesEvent && sameDate && s.records.isNotEmpty;
      });

      final notificationId = getNotificationId(event.id, sessionDate);

      if (isRecorded) {
        // Attendance already recorded -> suppress/cancel reminder
        await _notifications.cancel(id: notificationId);
        continue;
      }

      final scheduledReminderTime = calculateReminderTime(
        event: event,
        targetDate: sessionDate,
        offset: offset,
      );

      // Only schedule if the reminder time is in the future
      if (scheduledReminderTime.isAfter(now)) {
        await _scheduleLocalNotification(
          id: notificationId,
          event: event,
          targetDate: sessionDate,
          scheduledTime: scheduledReminderTime,
        );
      } else {
        // Time has already passed and no reminder needed
        await _notifications.cancel(id: notificationId);
      }
    }
  }

  Future<void> _scheduleLocalNotification({
    required int id,
    required Event event,
    required DateTime targetDate,
    required DateTime scheduledTime,
  }) async {
    final payload = AttendanceReminderPayload(
      eventId: event.id,
      targetDateIso: targetDate.toIso8601String(),
    ).serialize();

    const androidDetails = AndroidNotificationDetails(
      notificationChannelId,
      notificationChannelName,
      channelDescription: notificationChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final location = _localLocation ?? tz.local;
    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, location);

    try {
      await _notifications.zonedSchedule(
        id: id,
        title: 'Reminder: ${event.title}',
        body: "Attendance hasn't been recorded yet for today's session.",
        scheduledDate: tzScheduledTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (_) {
      // In tests or unsupported platforms fallback gracefully
    }
  }
}
