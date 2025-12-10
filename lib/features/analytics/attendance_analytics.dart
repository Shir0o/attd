import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';

class AnalyticsDateRange {
  const AnalyticsDateRange({required this.start, required this.end, required this.label});

  final DateTime start;
  final DateTime end;
  final String label;

  bool includes(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return !normalized.isBefore(start) && !normalized.isAfter(end);
  }
}

enum AnalyticsRange {
  last7Days,
  last30Days,
  allTime,
}

extension AnalyticsRangeX on AnalyticsRange {
  AnalyticsDateRange resolve(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case AnalyticsRange.last7Days:
        return AnalyticsDateRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
          label: 'Last 7 days',
        );
      case AnalyticsRange.last30Days:
        return AnalyticsDateRange(
          start: today.subtract(const Duration(days: 29)),
          end: today,
          label: 'Last 30 days',
        );
      case AnalyticsRange.allTime:
        return AnalyticsDateRange(
          start: DateTime.fromMillisecondsSinceEpoch(0),
          end: today,
          label: 'All time',
        );
    }
  }

  String get label {
    switch (this) {
      case AnalyticsRange.last7Days:
        return 'Last 7 days';
      case AnalyticsRange.last30Days:
        return 'Last 30 days';
      case AnalyticsRange.allTime:
        return 'All time';
    }
  }
}

class AttendanceBreakdown {
  const AttendanceBreakdown({
    required this.present,
    required this.partial,
    required this.absent,
  });

  final int present;
  final int partial;
  final int absent;

  int get total => present + absent;

  double get rate => total == 0 ? 0 : present / total * 100;
}

class AttendeeInsight {
  const AttendeeInsight({
    required this.name,
    required this.present,
    required this.absent,
    required this.partial,
    required this.absenceStreak,
    required this.lateStreak,
  });

  final String name;
  final int present;
  final int absent;
  final int partial;
  final int absenceStreak;
  final int lateStreak;

  int get total => present + absent;
  double get attendanceRate => total == 0 ? 0 : present / total * 100;
}

class FamilyInsight {
  const FamilyInsight({
    required this.family,
    required this.present,
    required this.absent,
    required this.partial,
  });

  final Family family;
  final int present;
  final int absent;
  final int partial;

  int get total => present + absent;
  double get attendanceRate => total == 0 ? 0 : present / total * 100;
}

class WellnessFlag {
  const WellnessFlag({required this.subject, required this.reason, this.isFamily = false});

  final String subject;
  final String reason;
  final bool isFamily;
}

class AttendanceAnalytics {
  const AttendanceAnalytics({
    required this.breakdown,
    required this.attendees,
    required this.families,
    required this.trend,
    required this.watchlist,
    required this.range,
  });

  final AttendanceBreakdown breakdown;
  final Map<String, AttendeeInsight> attendees;
  final Map<String, FamilyInsight> families;
  final List<double> trend;
  final List<WellnessFlag> watchlist;
  final AnalyticsDateRange range;
}

AttendanceAnalytics calculateAttendanceAnalytics({
  required List<Session> sessions,
  required List<Family> families,
  required AnalyticsDateRange range,
}) {
  final filteredSessions = sessions
      .where((session) => range.includes(session.sessionDate))
      .toList()
    ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));

  final attendeeToFamily = _attendeeFamilyIndex(families);
  final attendeeRecords = <String, List<_RecordEvent>>{};
  var present = 0;
  var partial = 0;
  var absent = 0;

  for (final session in filteredSessions) {
    for (final record in session.records) {
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

      attendeeRecords.putIfAbsent(record.attendee, () => []);
      attendeeRecords[record.attendee]!.add(
        _RecordEvent(
          date: session.sessionDate,
          status: record.status,
        ),
      );
    }
  }

  final attendees = <String, AttendeeInsight>{};
  final familyCounters = <String, _FamilyCounter>{};

  attendeeRecords.forEach((attendee, entries) {
    entries.sort((a, b) => a.date.compareTo(b.date));
    final stats = _summarize(entries);
    attendees[attendee] = AttendeeInsight(
      name: attendee,
      present: stats.present,
      absent: stats.absent,
      partial: stats.partial,
      absenceStreak: _streak(entries, AttendanceStatus.absent),
      lateStreak: _streak(entries, AttendanceStatus.partial),
    );

    final familyId = attendeeToFamily[attendee];
    if (familyId != null) {
      familyCounters.putIfAbsent(familyId, () => _FamilyCounter());
      familyCounters[familyId] = familyCounters[familyId]!.add(stats);
    }
  });

  final familyInsights = <String, FamilyInsight>{};
  for (final family in families) {
    final counter = familyCounters[family.id] ?? _FamilyCounter();
    familyInsights[family.id] = FamilyInsight(
      family: family,
      present: counter.present,
      absent: counter.absent,
      partial: counter.partial,
    );
  }

  final watchlist = _buildWatchlist(attendees, familyInsights.values.toList());

  return AttendanceAnalytics(
    breakdown: AttendanceBreakdown(present: present, partial: partial, absent: absent),
    attendees: attendees,
    families: familyInsights,
    trend: _buildTrend(filteredSessions),
    watchlist: watchlist,
    range: range,
  );
}

List<double> _buildTrend(List<Session> sessions) {
  final points = <double>[];
  for (final session in sessions) {
    if (session.records.isEmpty) continue;
    final presentCount = session.records
        .where((record) => record.status == AttendanceStatus.present)
        .length;
    final lateCount =
        session.records.where((record) => record.status == AttendanceStatus.partial).length;
    final rate = (presentCount + lateCount) / session.records.length * 100;
    points.add(double.parse(rate.toStringAsFixed(1)));
  }
  return points;
}

List<WellnessFlag> _buildWatchlist(
  Map<String, AttendeeInsight> attendees,
  List<FamilyInsight> families,
) {
  final flags = <WellnessFlag>[];

  attendees.forEach((name, insight) {
    if (insight.absenceStreak >= 2) {
      flags.add(
        WellnessFlag(
          subject: name,
          reason: '${insight.absenceStreak} consecutive absences',
        ),
      );
    } else if (insight.lateStreak >= 2) {
      flags.add(
        WellnessFlag(
          subject: name,
          reason: 'Late ${insight.lateStreak} times in a row',
        ),
      );
    } else if (insight.total >= 3 && insight.attendanceRate < 75) {
      flags.add(
        WellnessFlag(
          subject: name,
          reason: 'Attendance dropped to ${insight.attendanceRate.toStringAsFixed(0)}%',
        ),
      );
    }
  });

  for (final family in families) {
    if (family.total >= 3 && family.attendanceRate < 70) {
      flags.add(
        WellnessFlag(
          subject: family.family.displayName,
          reason: 'Family attendance at ${family.attendanceRate.toStringAsFixed(0)}%',
          isFamily: true,
        ),
      );
    }
  }

  flags.sort((a, b) => a.subject.compareTo(b.subject));
  return flags;
}

_MapSummary _summarize(List<_RecordEvent> entries) {
  var present = 0;
  var partial = 0;
  var absent = 0;
  for (final entry in entries) {
    switch (entry.status) {
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
  return _MapSummary(present: present, absent: absent, partial: partial);
}

int _streak(List<_RecordEvent> entries, AttendanceStatus status) {
  var streak = 0;
  for (final entry in entries.reversed) {
    if (entry.status == status) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

Map<String, String> _attendeeFamilyIndex(List<Family> families) {
  final index = <String, String>{};
  for (final family in families) {
    for (final member in family.members) {
      index[member.displayName] = family.id;
    }
  }
  return index;
}

class _RecordEvent {
  const _RecordEvent({required this.date, required this.status});

  final DateTime date;
  final AttendanceStatus status;
}

class _MapSummary {
  const _MapSummary({required this.present, required this.absent, required this.partial});

  final int present;
  final int absent;
  final int partial;
}

class _FamilyCounter {
  const _FamilyCounter({this.present = 0, this.absent = 0, this.partial = 0});

  final int present;
  final int absent;
  final int partial;

  _FamilyCounter add(_MapSummary summary) {
    return _FamilyCounter(
      present: present + summary.present,
      absent: absent + summary.absent,
      partial: partial + summary.partial,
    );
  }
}
