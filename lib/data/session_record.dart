import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';

class SessionRecord {
  const SessionRecord({
    this.memberId,
    required this.attendee,
    required this.status,
    required this.recordedAt,
    required this.recordedBy,
    bool isLate = false,
  }) : isLate = isLate && status == AttendanceStatus.present;

  final String? memberId;
  final String attendee;
  final AttendanceStatus status;
  final DateTime recordedAt;
  final String recordedBy;

  /// Present-but-late flag. Only meaningful when [status] is present: an
  /// absent record coerces this to false at construction (see the initializer
  /// above), so no call site can persist a late flag on an absent record.
  final bool isLate;

  SessionRecord copyWith({
    String? memberId,
    String? attendee,
    AttendanceStatus? status,
    DateTime? recordedAt,
    String? recordedBy,
    bool? isLate,
  }) {
    return SessionRecord(
      memberId: memberId ?? this.memberId,
      attendee: attendee ?? this.attendee,
      status: status ?? this.status,
      recordedAt: recordedAt ?? this.recordedAt,
      recordedBy: recordedBy ?? this.recordedBy,
      isLate: isLate ?? this.isLate,
    );
  }

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    return SessionRecord(
      memberId: json['memberId'] as String?,
      attendee: json['attendee'] as String,
      status: AttendanceStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => AttendanceStatus.absent,
      ),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      recordedBy: json['recordedBy'] as String,
      isLate: json['isLate'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'memberId': memberId,
      'attendee': attendee,
      'status': status.name,
      'recordedAt': recordedAt.toIso8601String(),
      'recordedBy': recordedBy,
      'isLate': isLate,
    };
  }
}
