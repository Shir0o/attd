import 'package:flutter/material.dart';
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
      // If today is the day, return it. Otherwise return the scheduled date.
      // Or simply return the scheduled date always? The prompt says "previous week"
      // logic applies to "weekly repeating event".
      // For one-time, let's stick to the scheduled date.
      return oneTime;
    }
    return today;
  }

  // 2. Check if today is a repeating day
  // (The caller usually filters this, but let's be safe or just assume 'now' is the relevant context)

  // 3. Compare Time
  final eventTime = DateTime(
    now.year,
    now.month,
    now.day,
    event.time.hour,
    event.time.minute,
  );

  // If we are BEFORE the scheduled time on the same day
  if (now.isBefore(eventTime)) {
    switch (event.frequency) {
      case 'Weekly':
        return today.subtract(const Duration(days: 7));
      case 'Bi-weekly':
        return today.subtract(const Duration(days: 14));
      case 'Monthly':
        // Subtracting a month can be tricky (e.g. March 31 -> Feb 28/29)
        // Simple approach: go to first day of previous month, then try to match day.
        // Or just subtract 30 days?
        // Let's do logical month subtraction.
        int newYear = today.year;
        int newMonth = today.month - 1;
        if (newMonth < 1) {
          newYear--;
          newMonth = 12;
        }
        final daysInNewMonth = DateUtils.getDaysInMonth(newYear, newMonth);
        final newDay = today.day > daysInNewMonth ? daysInNewMonth : today.day;
        return DateTime(newYear, newMonth, newDay);
      default:
        return today;
    }
  }

  // Otherwise, return today
  return today;
}
