import 'package:flutter/material.dart';

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

  /// Per-event Insights presets: viewing range, Regular and Lapsed thresholds,
  /// and which sections show. `null` means nothing has been chosen and the
  /// defaults apply. See ADR 0007.
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Event && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
