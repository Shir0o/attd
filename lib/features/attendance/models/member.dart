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
  }) : displayName = displayName.trim(),
       canonicalName = (canonicalName ?? displayName).trim(),
       labels = labels ?? const LabelAssignments();

  Member copyWith({
    String? id,
    String? displayName,
    String? canonicalName,
    String? mergedIntoMemberId,
    bool? isVisitor,
    AttendanceStatus? defaultStatus,
    LabelAssignments? labels,
  }) {
    return Member(
      id: id ?? this.id,
      displayName: (displayName ?? this.displayName).trim(),
      canonicalName: (canonicalName ?? this.canonicalName).trim(),
      mergedIntoMemberId: mergedIntoMemberId ?? this.mergedIntoMemberId,
      isVisitor: isVisitor ?? this.isVisitor,
      defaultStatus: defaultStatus ?? this.defaultStatus,
      labels: labels ?? this.labels,
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
    };
  }
}
