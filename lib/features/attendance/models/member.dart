import 'attendance_status.dart';

import 'label_assignments.dart';

class Member {
  final String id;
  final String displayName;
  final String canonicalName;
  final String? mergedIntoMemberId;
  final bool isVisitor;
  final AttendanceStatus defaultStatus;
  final LabelAssignments labels;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  late final String displayNameLowercase = displayName.toLowerCase();
  late final String canonicalNameLowercase = canonicalName.toLowerCase();

  Member({
    required this.id,
    required String displayName,
    String? canonicalName,
    this.mergedIntoMemberId,
    this.isVisitor = false,
    this.defaultStatus = AttendanceStatus.absent,
    LabelAssignments? labels,
    DateTime? updatedAt,
    this.deletedAt,
  }) : displayName = displayName.trim(),
       canonicalName = (canonicalName ?? displayName).trim(),
       labels = labels ?? LabelAssignments.empty,
       updatedAt = updatedAt ?? DateTime.now();

  Member copyWith({
    String? id,
    String? displayName,
    String? canonicalName,
    String? mergedIntoMemberId,
    bool? isVisitor,
    AttendanceStatus? defaultStatus,
    LabelAssignments? labels,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Member(
      id: id ?? this.id,
      displayName: (displayName ?? this.displayName).trim(),
      canonicalName: (canonicalName ?? this.canonicalName).trim(),
      mergedIntoMemberId: mergedIntoMemberId ?? this.mergedIntoMemberId,
      isVisitor: isVisitor ?? this.isVisitor,
      defaultStatus: defaultStatus ?? this.defaultStatus,
      labels: labels ?? this.labels,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      displayName: (json['displayName'] as String).trim(),
      canonicalName: (json['canonicalName'] as String?)?.trim(),
      mergedIntoMemberId: json['mergedIntoMemberId'] as String?,
      isVisitor: json['isVisitor'] as bool? ?? false,
      defaultStatus: AttendanceStatus.values.firstWhere(
        (status) => status.name == json['defaultStatus'],
        orElse: () => AttendanceStatus.absent,
      ),
      labels: LabelAssignments.fromJson(
        json['labels'] as Map<String, dynamic>?,
      ),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'canonicalName': canonicalName,
      'mergedIntoMemberId': mergedIntoMemberId,
      'isVisitor': isVisitor,
      'defaultStatus': defaultStatus.name,
      'labels': labels.toJson(),
      'updatedAt': updatedAt.toIso8601String(),
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    };
  }
}
