# ADR 0010: Local Scheduled Attendance Reminders and Suppression

- Status: Accepted
- Date: 2026-10-25

## Context

Attendance Tracker is an offline-first, privacy-focused application for adult group coordinators. Event organizers often schedule events (weekly, bi-weekly, one-time) and may forget to take attendance during busy meetings. 

To ensure records are captured consistently without violating zero-telemetry, zero-remote-server privacy principles:
1. Reminders must run locally on the device with zero outbound network calls.
2. A reminder should not disturb the coordinator if attendance has already been recorded for that session.
3. The UI must follow the "Convocation" design specification (`DESIGN_SPEC.md`): editorial typography, no 1px borders (tonal sectioning), and fluid controls.

## Decision

1. **Local Notification Scheduling (`flutter_local_notifications`)**:
   - Use purely local OS alarm scheduling via `flutter_local_notifications`.
   - Never register device push tokens or rely on remote push servers.
   - Request OS notification permission explicitly only when the user toggles on Attendance Reminders in Settings.

2. **Suppression on Recorded Attendance**:
   - When a session's attendance marks are saved for an event on a given date, any pending notification for that event's session is cancelled/dismissed immediately.
   - When scheduling reminders (e.g. upon app resume or event reschedule), verify whether a historical `Session` already exists for today's date before queueing the local notification.

3. **Settings & Preset Offsets**:
   - Add a dedicated **Reminders** section in `SettingsPage`.
   - Provide an on/off master switch (`attendance_reminders_enabled`, default `false`).
   - When enabled, display a discrete `Reminder Offset` selector:
     - At scheduled start time (0 min)
     - 15 minutes after
     - 30 minutes after
     - 1 hour after (default)
     - 2 hours after
   - Persist settings via `SharedPreferences`.

4. **Deep Linking to Session Attendance**:
   - Tapping the reminder notification launches the application and navigates directly into the attendance-taking flow for that specific event and date.

## Alternatives Considered

| Alternative | Why we passed |
| --- | --- |
| **Remote Push (FCM / APNs backend)** | Requires backend server, database of user schedules, token tracking, and leaks user schedule data. Violates local-first zero-leak architecture. |
| **WorkManager polling** | Consumes excess battery waking up the app in background to inspect times, rather than using the native OS alarm/notification scheduler. |
| **Fixed Time of Day (e.g. 8:00 PM)** | Unhelpful for groups meeting at varying times throughout the week (e.g. morning vs evening events). Start-time offset provides immediate context. |

## Consequences

### Positive
- Zero network exposure; 100% offline, privacy-preserving.
- Deep linking removes friction for late marks.
- Automatic cancellation when attendance is taken prevents annoying redundant alerts.

### Negative
- Platform differences in exact local alarm scheduling (e.g. Android 12+ exact alarm policies) must be managed cleanly.
