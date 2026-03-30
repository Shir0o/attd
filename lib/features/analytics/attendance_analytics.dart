import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/label_assignments.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';

class AnalyticsDateRange {
  const AnalyticsDateRange({
    required this.start,
    required this.end,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final String label;

  bool includes(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return !normalized.isBefore(start) && !normalized.isAfter(end);
  }
}

enum AnalyticsRange { last7Days, last30Days, allTime }

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
  const AttendanceBreakdown({required this.present, required this.absent});

  final int present;
  final int absent;

  int get total => present + absent;

  double get rate => total == 0 ? 0 : present / total * 100;
}

class AttendeeInsight {
  const AttendeeInsight({
    required this.name,
    required this.present,
    required this.absent,
    required this.absenceStreak,
  });

  final String name;
  final int present;
  final int absent;
  final int absenceStreak;

  int get total => present + absent;
  double get attendanceRate => total == 0 ? 0 : present / total * 100;
}

class FamilyInsight {
  FamilyInsight({
    required this.family,
    required this.present,
    required this.absent,
  });

  final Family family;
  final int present;
  final int absent;

  int get total => present + absent;
  double get attendanceRate => total == 0 ? 0 : present / total * 100;
}

class WellnessFlag {
  const WellnessFlag({
    required this.subject,
    required this.reason,
    this.isFamily = false,
  });

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
  final filteredSessions =
      sessions.where((session) => range.includes(session.sessionDate)).toList()
        ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));

  final familiesById = {for (final family in families) family.id: family};
  final membersById = {
    for (final family in families)
      for (final member in family.members) member.id: member,
  };

  final visited = <String>{};

  final attendeeToFamily = _attendeeFamilyIndex(
    families,
    familiesById,
    membersById,
    visited,
  );

  final attendeeLookup = <String, String>{};
  for (final member in membersById.values) {
    final canonical = _resolveMember(member, membersById, visited).canonicalName;
    attendeeLookup.putIfAbsent(member.displayNameLowercase, () => canonical);
    attendeeLookup.putIfAbsent(member.canonicalNameLowercase, () => canonical);
  }
  for (final family in families) {
    final canonical = _resolveFamily(family, familiesById, visited).canonicalName;
    attendeeLookup.putIfAbsent(family.displayNameLowercase, () => canonical);
    attendeeLookup.putIfAbsent(family.canonicalNameLowercase, () => canonical);
  }

  final memberLabels = _memberLabelIndex(families, membersById, visited);
  final familyLabels = _familyLabelIndex(families, familiesById, visited);
  final canonicalFamilies = _canonicalFamilies(families, familiesById, visited);

  final attendeeRecords = <String, List<_RecordEvent>>{};
  var present = 0;
  var absent = 0;

  for (final session in filteredSessions) {
    for (final record in session.records) {
      String canonicalName;
      if (record.memberId != null && membersById.containsKey(record.memberId)) {
        final member = membersById[record.memberId]!;
        canonicalName =
            _resolveMember(member, membersById, visited).canonicalName;
      } else {
        canonicalName = _canonicalizeAttendee(record.attendee, attendeeLookup);
      }
      
      switch (record.status) {
        case AttendanceStatus.present:
          present++;
          break;
        case AttendanceStatus.absent:
          absent++;
          break;
      }

      attendeeRecords.putIfAbsent(canonicalName, () => []);
      attendeeRecords[canonicalName]!.add(
        _RecordEvent(date: session.sessionDate, status: record.status),
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
      absenceStreak: _streak(entries, AttendanceStatus.absent),
    );

    final familyId = attendeeToFamily[attendee];
    if (familyId != null) {
      familyCounters.putIfAbsent(familyId, () => _FamilyCounter());
      familyCounters[familyId] = familyCounters[familyId]!.add(stats);
    }
  });

  final familyInsights = <String, FamilyInsight>{};
  for (final family in canonicalFamilies.values) {
    final counter = familyCounters[family.id] ?? _FamilyCounter();
    familyInsights[family.id] = FamilyInsight(
      family: family,
      present: counter.present,
      absent: counter.absent,
    );
  }

  final watchlist = _buildWatchlist(
    attendees,
    familyInsights.values.toList(),
    memberLabels,
    familyLabels,
  );

  return AttendanceAnalytics(
    breakdown: AttendanceBreakdown(present: present, absent: absent),
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
    final rate = session.records.isEmpty
        ? 0
        : presentCount / session.records.length * 100;
    points.add(double.parse(rate.toStringAsFixed(1)));
  }
  return points;
}

List<WellnessFlag> _buildWatchlist(
  Map<String, AttendeeInsight> attendees,
  List<FamilyInsight> families,
  Map<String, LabelAssignments> memberLabels,
  Map<String, LabelAssignments> familyLabels,
) {
  final flags = <String, WellnessFlag>{};

  void addFlag(String subject, String reason, {bool isFamily = false}) {
    flags.putIfAbsent(
      subject,
      () => WellnessFlag(subject: subject, reason: reason, isFamily: isFamily),
    );
  }

  memberLabels.forEach((name, labels) {
    if (labels.hasLabel(watchlistLabel)) {
      final reason = labels.isManual(watchlistLabel)
          ? 'Manually added to watchlist'
          : 'Watchlist label applied';
      addFlag(name, reason);
    }
  });

  attendees.forEach((name, insight) {
    if (flags.containsKey(name)) return;
    if (insight.absenceStreak >= 2) {
      addFlag(name, '${insight.absenceStreak} consecutive absences');
    } else if (insight.total >= 3 && insight.attendanceRate < 75) {
      addFlag(
        name,
        'Attendance dropped to ${insight.attendanceRate.toStringAsFixed(0)}%',
      );
    }
  });

  familyLabels.forEach((name, labels) {
    if (labels.hasLabel(watchlistLabel)) {
      final reason = labels.isManual(watchlistLabel)
          ? 'Manually added to watchlist'
          : 'Watchlist label applied';
      addFlag(name, reason, isFamily: true);
    }
  });

  for (final family in families) {
    if (flags.containsKey(family.family.canonicalName)) continue;
    if (family.total >= 3 && family.attendanceRate < 70) {
      addFlag(
        family.family.canonicalName,
        'Family attendance at ${family.attendanceRate.toStringAsFixed(0)}%',
        isFamily: true,
      );
    }
  }

  final values = flags.values.toList()
    ..sort((a, b) => a.subject.compareTo(b.subject));
  return values;
}

_MapSummary _summarize(List<_RecordEvent> entries) {
  var present = 0;
  var absent = 0;
  for (final entry in entries) {
    switch (entry.status) {
      case AttendanceStatus.present:
        present++;
        break;
      case AttendanceStatus.absent:
        absent++;
        break;
    }
  }
  return _MapSummary(present: present, absent: absent);
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

String _canonicalizeAttendee(String attendee, Map<String, String> lookup) {
  return lookup[attendee.toLowerCase()] ?? attendee;
}

Family _resolveFamily(
  Family family,
  Map<String, Family> familiesById,
  [Set<String>? visited,]
) {
  var current = family;
  final usedVisited = visited ?? <String>{};
  if (visited != null) visited.clear();

  while (current.mergedIntoFamilyId != null &&
      !usedVisited.contains(current.mergedIntoFamilyId!)) {
    final target = familiesById[current.mergedIntoFamilyId!];
    if (target == null) break;
    usedVisited.add(current.mergedIntoFamilyId!);
    current = target;
  }
  return current;
}

Member _resolveMember(
  Member member,
  Map<String, Member> membersById,
  [Set<String>? visited,]
) {
  var current = member;
  final usedVisited = visited ?? <String>{};
  if (visited != null) visited.clear();

  while (current.mergedIntoMemberId != null &&
      !usedVisited.contains(current.mergedIntoMemberId!)) {
    final target = membersById[current.mergedIntoMemberId!];
    if (target == null) break;
    usedVisited.add(current.mergedIntoMemberId!);
    current = target;
  }
  return current;
}

Map<String, String> _attendeeFamilyIndex(
  List<Family> families,
  Map<String, Family> familiesById,
  Map<String, Member> membersById,
  [Set<String>? visited,]
) {
  final index = <String, String>{};
  for (final family in families) {
    final canonicalFamily = _resolveFamily(family, familiesById, visited);
    for (final member in family.members) {
      final canonicalMember = _resolveMember(member, membersById, visited);
      index[canonicalMember.canonicalName] = canonicalFamily.id;
    }
  }
  return index;
}

Map<String, LabelAssignments> _memberLabelIndex(
  List<Family> families,
  Map<String, Member> membersById,
  [Set<String>? visited,]
) {
  final index = <String, LabelAssignments>{};
  for (final family in families) {
    for (final member in family.members) {
      final canonical = _resolveMember(member, membersById, visited);
      index[canonical.canonicalName] = _mergeLabelAssignments(
        index[canonical.canonicalName],
        [member.labels, canonical.labels],
      );
    }
  }
  return index;
}

Map<String, LabelAssignments> _familyLabelIndex(
  List<Family> families,
  Map<String, Family> familiesById,
  [Set<String>? visited,]
) {
  final index = <String, LabelAssignments>{};
  for (final family in families) {
    final canonical = _resolveFamily(family, familiesById, visited);
    index[canonical.canonicalName] = _mergeLabelAssignments(
      index[canonical.canonicalName],
      [family.labels, canonical.labels],
    );
  }
  return index;
}

Map<String, Family> _canonicalFamilies(
  List<Family> families,
  Map<String, Family> familiesById,
  [Set<String>? visited,]
) {
  final canonical = <String, Family>{};
  for (final family in families) {
    final resolved = _resolveFamily(family, familiesById, visited);
    canonical[resolved.id] = resolved;
  }
  return canonical;
}

LabelAssignments _mergeLabelAssignments(
  LabelAssignments? existing,
  Iterable<LabelAssignments> additions,
) {
  final auto = <String>{...existing?.autoLabels ?? {}};
  final manual = <String>{...existing?.manualLabels ?? {}};
  for (final assignment in additions) {
    auto.addAll(assignment.autoLabels);
    manual.addAll(assignment.manualLabels);
  }
  return LabelAssignments(autoLabels: auto, manualLabels: manual);
}

class _RecordEvent {
  const _RecordEvent({required this.date, required this.status});

  final DateTime date;
  final AttendanceStatus status;
}

class _MapSummary {
  const _MapSummary({required this.present, required this.absent});

  final int present;
  final int absent;
}

class _FamilyCounter {
  const _FamilyCounter({this.present = 0, this.absent = 0});

  final int present;
  final int absent;

  _FamilyCounter add(_MapSummary summary) {
    return _FamilyCounter(
      present: (present + summary.present).toInt(),
      absent: (absent + summary.absent).toInt(),
    );
  }
}
