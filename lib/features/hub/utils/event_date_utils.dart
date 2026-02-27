import '../domain/event.dart';

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

/// Finds the most recent date an event was supposed to occur,
/// including today if the event time has passed.
DateTime getLastSupposedOccurrence(Event event, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);

  if (event.frequency == 'One-time') {
    return event.oneTimeDate ?? today;
  }

  final Map<String, int> weekdays = {
    'Monday': DateTime.monday,
    'Tuesday': DateTime.tuesday,
    'Wednesday': DateTime.wednesday,
    'Thursday': DateTime.thursday,
    'Friday': DateTime.friday,
    'Saturday': DateTime.saturday,
    'Sunday': DateTime.sunday,
  };

  final eventWeekdays = event.repeatingDays.map((d) => weekdays[d]!).toList();
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
    final prev = today.subtract(Duration(days: i));
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
