import '../domain/event.dart';

/// Maps the day names stored on [Event.repeatingDays] to `DateTime` weekday ints.
const Map<String, int> _weekdayMap = {
  'Monday': DateTime.monday,
  'Tuesday': DateTime.tuesday,
  'Wednesday': DateTime.wednesday,
  'Thursday': DateTime.thursday,
  'Friday': DateTime.friday,
  'Saturday': DateTime.saturday,
  'Sunday': DateTime.sunday,
};

/// Calculates the target session date for an event based on the current time.
///
/// If the event is a 'One-time' event, it returns the scheduled date or today.
/// For recurring events, if the current time is before the event's scheduled time
/// (on the same day), it assumes the user intends to view/log the *previous*
/// occurrence of the event.
///
/// - Weekly: Returns the date 7 days ago.
/// - Bi-weekly: Returns the date 14 days ago.
/// - Monthly: Returns the date 1 month ago (approx 30 days or same day last month).
///
/// Otherwise (if time has passed or it's a different day), it returns today's date.
DateTime calculateTargetDate(Event event, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);

  // 1. Handle One-time events
  if (event.frequency == 'One-time') {
    if (event.oneTimeDate != null) {
      final oneTime = DateTime(
        event.oneTimeDate!.year,
        event.oneTimeDate!.month,
        event.oneTimeDate!.day,
      );
      return oneTime;
    }
    return today;
  }

  // 2. For repeating events, find the last (or current) supposed occurrence
  return getLastSupposedOccurrence(event, now);
}

/// Steps [days] calendar days from [day], keeping local midnight.
///
/// [DateTime.add] and [DateTime.subtract] move by an absolute duration, so a
/// whole-day step across a daylight-saving boundary lands on 01:00 or 23:00.
/// Comparing that against a session date (which is local midnight) then makes a
/// recorded occurrence look like it has not been recorded. Calendar arithmetic
/// (`DateTime(y, m, d + n)`) keeps the date and the midnight.
DateTime _addCalendarDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// Finds the next date an event is supposed to occur, on or after today.
///
/// For repeating events, today only counts if its scheduled time hasn't passed
/// yet; otherwise the search rolls forward to the next matching weekday.
DateTime getNextOccurrence(Event event, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);

  if (event.frequency == 'One-time') {
    if (event.oneTimeDate == null) return today;
    return DateTime(
      event.oneTimeDate!.year,
      event.oneTimeDate!.month,
      event.oneTimeDate!.day,
    );
  }

  final eventWeekdays = event.repeatingDays
      .map((d) => _weekdayMap[d])
      .whereType<int>()
      .toList();
  if (eventWeekdays.isEmpty) return today;

  // Today, if the scheduled time is still ahead.
  if (eventWeekdays.contains(now.weekday)) {
    final eventTime = DateTime(
      now.year,
      now.month,
      now.day,
      event.time.hour,
      event.time.minute,
    );
    if (!now.isAfter(eventTime)) {
      return today;
    }
  }

  for (int i = 1; i <= 7; i++) {
    final next = _addCalendarDays(today, i);
    if (eventWeekdays.contains(next.weekday)) {
      return next;
    }
  }

  return today;
}

/// Finds the most recent date an event was supposed to occur,
/// including today if the event time has passed.
DateTime getLastSupposedOccurrence(Event event, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);

  if (event.frequency == 'One-time') {
    if (event.oneTimeDate == null) return today;
    return DateTime(
      event.oneTimeDate!.year,
      event.oneTimeDate!.month,
      event.oneTimeDate!.day,
    );
  }

  final eventWeekdays = event.repeatingDays
      .map((d) => _weekdayMap[d])
      .whereType<int>()
      .toList();
  if (eventWeekdays.isEmpty) return today;

  // Check today
  if (eventWeekdays.contains(now.weekday)) {
    final eventTime = DateTime(
      now.year,
      now.month,
      now.day,
      event.time.hour,
      event.time.minute,
    );
    if (!now.isBefore(eventTime)) {
      return today;
    }
  }

  // Search backwards for the last occurrence
  final creationDate = DateTime(
    event.createdAt.year,
    event.createdAt.month,
    event.createdAt.day,
  );

  for (int i = 1; i <= 7; i++) {
    final prev = _addCalendarDays(today, -i);
    if (eventWeekdays.contains(prev.weekday)) {
      // Don't suggest an occurrence before the event was even created
      if (prev.isBefore(creationDate)) {
        return today.isBefore(creationDate) ? creationDate : today;
      }
      return prev;
    }
  }

  return today.isBefore(creationDate) ? creationDate : today;
}
