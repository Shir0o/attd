import 'package:flutter/material.dart';

class Event {
  final String id;
  final String title;
  final TimeOfDay time;
  final String frequency; // 'One-time', 'Weekly', 'Bi-weekly', 'Monthly'
  final DateTime? oneTimeDate; // For 'One-time' events
  final List<String>
  repeatingDays; // For repeating events (e.g., ['Monday', 'Wednesday'])
  final List<String> memberIds; // Members associated with this event
  final DateTime createdAt;
  final DateTime updatedAt;

  Event({
    required this.id,
    required this.title,
    required this.time,
    required this.frequency,
    this.oneTimeDate,
    this.repeatingDays = const [],
    this.memberIds = const [],
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'time': '${time.hour}:${time.minute}',
      'frequency': frequency,
      'oneTimeDate': oneTimeDate?.toIso8601String(),
      'repeatingDays': repeatingDays,
      'memberIds': memberIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    final timeParts = (json['time'] as String).split(':');
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
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
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.parse(json['createdAt'] as String),
    );
  }
}
