import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/reminders/application/attendance_reminder_service.dart';
import 'package:attendance_tracker/features/reminders/application/reminder_settings_controller.dart';
import 'package:attendance_tracker/features/reminders/domain/reminder_offset_preset.dart';

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class MockEventRepository extends Mock implements EventRepository {}

class MockSessionRepository extends Mock implements SessionRepository {}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    registerFallbackValue(
      const NotificationDetails(),
    );
    registerFallbackValue(
      AndroidScheduleMode.exactAllowWhileIdle,
    );
    registerFallbackValue(
      tz.TZDateTime.now(tz.local),
    );
  });

  group('AttendanceReminderPayload', () {
    test('serializes and deserializes cleanly', () {
      const payload = AttendanceReminderPayload(
        eventId: 'evt-123',
        targetDateIso: '2026-10-25T00:00:00.000',
      );
      final json = payload.serialize();
      final parsed = AttendanceReminderPayload.deserialize(json);

      expect(parsed, isNotNull);
      expect(parsed!.eventId, 'evt-123');
      expect(parsed.targetDateIso, '2026-10-25T00:00:00.000');
    });

    test('returns null for empty or invalid json', () {
      expect(AttendanceReminderPayload.deserialize(null), isNull);
      expect(AttendanceReminderPayload.deserialize(''), isNull);
      expect(AttendanceReminderPayload.deserialize('invalid json'), isNull);
    });
  });

  group('AttendanceReminderService', () {
    late MockFlutterLocalNotificationsPlugin mockNotifications;
    late MockEventRepository mockEventRepo;
    late MockSessionRepository mockSessionRepo;
    late ReminderSettingsController settingsController;
    late SharedPreferences prefs;

    setUp(() async {
      mockNotifications = MockFlutterLocalNotificationsPlugin();
      mockEventRepo = MockEventRepository();
      mockSessionRepo = MockSessionRepository();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      settingsController = ReminderSettingsController(prefs: prefs);

      when(() => mockNotifications.cancel(id: any(named: 'id'))).thenAnswer((_) async {});
      when(() => mockNotifications.cancelAll()).thenAnswer((_) async {});
    });

    test('calculateReminderTime adds offset to event start time', () {
      final service = AttendanceReminderService(
        notificationsPlugin: mockNotifications,
        settingsController: settingsController,
        eventRepository: mockEventRepo,
        sessionRepository: mockSessionRepo,
      );

      final event = Event(
        id: 'e1',
        title: 'Sunday Service',
        time: const TimeOfDay(hour: 10, minute: 0),
        frequency: 'Weekly',
        repeatingDays: ['Sunday'],
        createdAt: DateTime(2026, 1, 1),
      );

      final sessionDate = DateTime(2026, 10, 25);
      final reminderTime = service.calculateReminderTime(
        event: event,
        targetDate: sessionDate,
        offset: const Duration(hours: 1),
      );

      expect(reminderTime, DateTime(2026, 10, 25, 11, 0));
    });

    test('syncReminders cancels all when settingsController is disabled', () async {
      final service = AttendanceReminderService(
        notificationsPlugin: mockNotifications,
        settingsController: settingsController,
        eventRepository: mockEventRepo,
        sessionRepository: mockSessionRepo,
      );

      await service.syncReminders();

      verify(() => mockNotifications.cancelAll()).called(1);
    });

    test('syncReminders cancels notification when session attendance is already recorded', () async {
      await settingsController.setEnabled(true);

      final event = Event(
        id: 'e1',
        title: 'Prayer Meeting',
        time: const TimeOfDay(hour: 19, minute: 0),
        frequency: 'One-time',
        oneTimeDate: DateTime(2026, 10, 25),
        createdAt: DateTime(2026, 1, 1),
      );

      final recordedSession = Session(
        id: 's1',
        title: 'Prayer Meeting',
        eventId: 'e1',
        sessionDate: DateTime(2026, 10, 25),
        records: [
          SessionRecord(
            attendee: 'John Doe',
            memberId: 'm1',
            status: AttendanceStatus.present,
            recordedAt: DateTime(2026, 10, 25, 19, 15),
            recordedBy: 'Admin',
          ),
        ],
        createdAt: DateTime(2026, 10, 25),
        updatedAt: DateTime(2026, 10, 25),
        createdBy: 'Admin',
      );

      when(() => mockEventRepo.fetchAllEvents()).thenAnswer((_) async => [event]);
      when(() => mockSessionRepo.fetchAllSessions())
          .thenAnswer((_) async => [recordedSession]);

      final service = AttendanceReminderService(
        notificationsPlugin: mockNotifications,
        settingsController: settingsController,
        eventRepository: mockEventRepo,
        sessionRepository: mockSessionRepo,
      );

      final now = DateTime(2026, 10, 25, 18, 0);
      await service.syncReminders(currentTime: now);

      final expectedId = service.getNotificationId(event.id, DateTime(2026, 10, 25));
      verify(() => mockNotifications.cancel(id: expectedId)).called(1);
    });

    test('syncReminders schedules notification when reminder time is in future and unrecorded', () async {
      await settingsController.setEnabled(true);
      await settingsController.setOffset(ReminderOffsetPreset.oneHour);

      final event = Event(
        id: 'e1',
        title: 'Midweek Study',
        time: const TimeOfDay(hour: 19, minute: 0),
        frequency: 'One-time',
        oneTimeDate: DateTime(2026, 10, 25),
        createdAt: DateTime(2026, 1, 1),
      );

      when(() => mockEventRepo.fetchAllEvents()).thenAnswer((_) async => [event]);
      when(() => mockSessionRepo.fetchAllSessions()).thenAnswer((_) async => []);
      when(() => mockNotifications.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            payload: any(named: 'payload'),
          )).thenAnswer((_) async {});

      final service = AttendanceReminderService(
        notificationsPlugin: mockNotifications,
        settingsController: settingsController,
        eventRepository: mockEventRepo,
        sessionRepository: mockSessionRepo,
      );

      // Now is 18:00, event is at 19:00, 1h offset makes reminder 20:00 (future)
      final now = DateTime(2026, 10, 25, 18, 0);
      await service.syncReminders(currentTime: now);

      final expectedId = service.getNotificationId(event.id, DateTime(2026, 10, 25));
      verify(() => mockNotifications.zonedSchedule(
            id: expectedId,
            title: 'Reminder: Midweek Study',
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: any(named: 'payload'),
          )).called(1);
    });
  });
}
