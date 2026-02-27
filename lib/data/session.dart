import 'session_record.dart';

class Session {
  const Session({
    required this.id,
    this.eventId,
    required this.title,
    required this.sessionDate,
    required this.records,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.currentVersion = 1,
  });

  final String id;
  final String? eventId;
  final String title;
  final DateTime sessionDate;
  final List<SessionRecord> records;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final int currentVersion;

  Session copyWith({
    String? id,
    String? eventId,
    String? title,
    DateTime? sessionDate,
    List<SessionRecord>? records,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    int? currentVersion,
  }) {
    return Session(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      sessionDate: sessionDate ?? this.sessionDate,
      records: records ?? this.records,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      currentVersion: currentVersion ?? this.currentVersion,
    );
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    final recordsJson = json['records'] as List<dynamic>? ?? [];
    return Session(
      id: json['id'] as String,
      eventId: json['eventId'] as String?,
      title: json['title'] as String,
      sessionDate: DateTime.parse(json['sessionDate'] as String),
      records: recordsJson
          .map(
            (record) => SessionRecord.fromJson(record as Map<String, dynamic>),
          )
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      createdBy: json['createdBy'] as String,
      currentVersion: json['currentVersion'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'title': title,
      'sessionDate': sessionDate.toIso8601String(),
      'records': records.map((record) => record.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'currentVersion': currentVersion,
    };
  }
}
