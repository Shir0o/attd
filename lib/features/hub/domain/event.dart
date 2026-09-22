import 'package:flutter/material.dart';

import '../../attendance/models/attendance_start_mode.dart';
import '../../attendance/models/marking_mode.dart';
import '../../attendance/models/roster_grouping.dart';
import '../../sessions/domain/insights_config.dart';

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

  /// Per-event preset for which fast marking surface the session offers beside
  /// the Deck and the List. `null` means never chosen — [resolvedMarkingMode]
  /// falls back to [kDefaultMarkingMode] rather than prompting, so existing
  /// events pick up the default without an extra step.
  final MarkingMode? markingMode;

  /// Per-event Insights presets: viewing range, Regular and Lapsed thresholds,
  /// and which sections show. `null` means nothing has been chosen and the
  /// defaults apply, exactly as for [markingMode]. See ADR 0007.
  final InsightsConfig? insightsConfig;

  final bool isShared;
  final String? sharedFolderId;
  final List<String> collaborators;
  final bool isReadOnly;
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
    this.markingMode,
    this.insightsConfig,
    this.isShared = false,
    this.sharedFolderId,
    this.collaborators = const [],
    this.isReadOnly = false,
    required this.createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  })  : title = title.trim(),
        updatedAt = updatedAt ?? createdAt;

  /// The fast marking mode this event actually uses, applying the default when
  /// none has been chosen.
  MarkingMode get resolvedMarkingMode => markingMode ?? kDefaultMarkingMode;

  /// The Insights presets this event actually uses, applying defaults when
  /// nothing has been chosen.
  InsightsConfig get resolvedInsightsConfig =>
      insightsConfig ?? const InsightsConfig();

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
      if (markingMode != null) 'markingMode': markingMode!.name,
      if (insightsConfig != null) ...insightsConfig!.toJson(),
      if (isShared) 'isShared': isShared,
      if (sharedFolderId != null) 'sharedFolderId': sharedFolderId,
      if (collaborators.isNotEmpty) 'collaborators': collaborators,
      if (isReadOnly) 'isReadOnly': isReadOnly,
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
    MarkingMode? markingMode,
    InsightsConfig? insightsConfig,
    bool? isShared,
    String? sharedFolderId,
    List<String>? collaborators,
    bool? isReadOnly,
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
      markingMode: markingMode ?? this.markingMode,
      insightsConfig: insightsConfig ?? this.insightsConfig,
      isShared: isShared ?? this.isShared,
      sharedFolderId: sharedFolderId ?? this.sharedFolderId,
      collaborators: collaborators ?? this.collaborators,
      isReadOnly: isReadOnly ?? this.isReadOnly,
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
    MarkingMode? mode;
    final modeKey = json['markingMode'] as String?;
    if (modeKey != null) {
      for (final m in MarkingMode.values) {
        if (m.name == modeKey) {
          mode = m;
          break;
        }
      }
    }
    final insights = InsightsConfig.fromJson(json);
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
      repeatingDays: (json['repeatingDays'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      memberIds: (json['memberIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      defaultAttendanceStartMode: startMode,
      rosterGrouping: grouping,
      markingMode: mode,
      insightsConfig: insights.isEmpty ? null : insights,
      isShared: json['isShared'] as bool? ?? false,
      sharedFolderId: json['sharedFolderId'] as String?,
      collaborators: (json['collaborators'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isReadOnly: json['isReadOnly'] as bool? ?? false,
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
