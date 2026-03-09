import 'attendance_status.dart';

import 'label_assignments.dart';

class Member {
  final String id;
  final String displayName;
  final String searchName;
  final String canonicalName;
  final String? mergedIntoMemberId;
  final bool isVisitor;
  final AttendanceStatus defaultStatus;
  final LabelAssignments labels;

  const Member({
    required this.id,
    required this.displayName,
    this.searchName = '',
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
    String? searchName,
    String? canonicalName,
    String? mergedIntoMemberId,
    bool? isVisitor,
    AttendanceStatus? defaultStatus,
    LabelAssignments? labels,
  }) {
    final newDisplayName = displayName ?? this.displayName;
    final newSearchName = searchName ??
        (displayName != null
            ? displayName.toLowerCase()
            : (this.searchName.isEmpty
                ? this.displayName.toLowerCase()
                : this.searchName));

    return Member(
      id: id ?? this.id,
      displayName: newDisplayName,
      searchName: newSearchName,
      canonicalName: canonicalName ?? this.canonicalName,
      mergedIntoMemberId: mergedIntoMemberId ?? this.mergedIntoMemberId,
      isVisitor: isVisitor ?? this.isVisitor,
      defaultStatus: defaultStatus ?? this.defaultStatus,
      labels: labels ?? this.labels,
    );
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    final displayName = json['displayName'] as String;
    final searchName = json['searchName'] as String?;

    return Member(
      id: json['id'] as String,
      displayName: displayName,
      searchName: (searchName == null || searchName.isEmpty)
          ? displayName.toLowerCase()
          : searchName,
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
      'searchName': searchName,
      'canonicalName': canonicalName,
      'mergedIntoMemberId': mergedIntoMemberId,
      'isVisitor': isVisitor,
      'defaultStatus': defaultStatus.name,
      'labels': labels.toJson(),
    };
  }
}
