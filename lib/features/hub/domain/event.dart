import 'package:flutter/material.dart';

import '../../attendance/models/attendance_start_mode.dart';
import '../../attendance/models/roster_grouping.dart';

class Event {
  final String id;
  final String title;
  final TimeOfDay time;
  final String frequency; // 'One-time', 'Weekly', 'Bi-weekly', 'Monthly'
  final DateTime? oneTimeDate; // For 'One-time' events
  final List<String>
  repeatingDays; // For repeating events (e.g., ['Monday', 'Wednesday'])
  final List<String> memberIds; // Members associated with this event
  final AttendanceStartMode? defaultAttendanceStartMode;

  /// Per-event preset for how the marking roster groups (status vs family).
  /// `null` means the user has not chosen yet — the first time attendance is
  /// taken they are asked (defaulting to status), and the choice is saved here.
  final RosterGrouping? rosterGrouping;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Event({
    required this.id,
    required String title,
    required this.time,
    required this.frequency,
    this.oneTimeDate,
    this.repeatingDays = const [],
    this.memberIds = const [],
    this.defaultAttendanceStartMode,
    this.rosterGrouping,
    required this.createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  }) : title = title.trim(),
       updatedAt = updatedAt ?? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'time': '${time.hour}:${time.minute}',
      'frequency': frequency,
      'oneTimeDate': oneTimeDate?.toIso8601String(),
      'repeatingDays': repeatingDays,
      'memberIds': memberIds,
      if (defaultAttendanceStartMode != null)
        'defaultAttendanceStartMode': defaultAttendanceStartMode!.name,
      if (rosterGrouping != null) 'rosterGrouping': rosterGrouping!.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    };
  }

  Event copyWith({
    String? id,
    String? title,
    TimeOfDay? time,
    String? frequency,
    DateTime? oneTimeDate,
    List<String>? repeatingDays,
    List<String>? memberIds,
    AttendanceStartMode? defaultAttendanceStartMode,
    RosterGrouping? rosterGrouping,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      time: time ?? this.time,
      frequency: frequency ?? this.frequency,
      oneTimeDate: oneTimeDate ?? this.oneTimeDate,
      repeatingDays: repeatingDays ?? this.repeatingDays,
      memberIds: memberIds ?? this.memberIds,
      defaultAttendanceStartMode:
          defaultAttendanceStartMode ?? this.defaultAttendanceStartMode,
      rosterGrouping: rosterGrouping ?? this.rosterGrouping,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    final timeParts = (json['time'] as String).split(':');
    AttendanceStartMode? startMode;
    final modeName = json['defaultAttendanceStartMode'] as String?;
    if (modeName != null) {
      for (final m in AttendanceStartMode.values) {
        if (m.name == modeName) {
          startMode = m;
          break;
        }
      }
    }
    RosterGrouping? grouping;
    final groupingName = json['rosterGrouping'] as String?;
    if (groupingName != null) {
      for (final g in RosterGrouping.values) {
        if (g.name == groupingName) {
          grouping = g;
          break;
        }
      }
    }
    return Event(
      id: json['id'] as String,
      title: (json['title'] as String).trim(),
      time: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
      frequency: json['frequency'] as String,
      oneTimeDate: json['oneTimeDate'] != null
          ? DateTime.parse(json['oneTimeDate'] as String)
          : null,
      repeatingDays:
          (json['repeatingDays'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      memberIds:
          (json['memberIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      defaultAttendanceStartMode: startMode,
      rosterGrouping: grouping,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.parse(json['createdAt'] as String),
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
    );
  }
}
