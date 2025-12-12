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

  const Member({
    required this.id,
    required this.displayName,
    String? canonicalName,
    this.mergedIntoMemberId,
    this.isVisitor = false,
    this.defaultStatus = AttendanceStatus.absent,
    LabelAssignments? labels,
  }) : canonicalName = canonicalName ?? displayName,
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
      displayName: displayName ?? this.displayName,
      canonicalName: canonicalName ?? this.canonicalName,
      mergedIntoMemberId: mergedIntoMemberId ?? this.mergedIntoMemberId,
      isVisitor: isVisitor ?? this.isVisitor,
      defaultStatus: defaultStatus ?? this.defaultStatus,
      labels: labels ?? this.labels,
    );
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      canonicalName: json['canonicalName'] as String?,
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
