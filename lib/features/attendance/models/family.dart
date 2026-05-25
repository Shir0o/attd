import 'label_assignments.dart';
import 'member.dart';

class Family {
  final String id;
  final String displayName;
  final String canonicalName;
  final String? mergedIntoFamilyId;
  final List<Member> members;
  final LabelAssignments labels;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// True when this family is just a per-member singleton bucket
  /// (auto-created when a member is added without an explicit family).
  /// Such families render as flat member rows in the roster list rather than
  /// as a group header — see [AttendanceRosterList].
  final bool isAutoSingleton;

  late final String displayNameLowercase = displayName.toLowerCase();
  late final String canonicalNameLowercase = canonicalName.toLowerCase();

  Family({
    required this.id,
    required String displayName,
    String? canonicalName,
    this.mergedIntoFamilyId,
    required this.members,
    LabelAssignments? labels,
    DateTime? updatedAt,
    this.deletedAt,
    this.isAutoSingleton = false,
  }) : displayName = displayName.trim(),
       canonicalName = (canonicalName ?? displayName).trim(),
       labels = labels ?? const LabelAssignments(),
       updatedAt = updatedAt ?? DateTime.now();

  Family copyWith({
    String? id,
    String? displayName,
    String? canonicalName,
    String? mergedIntoFamilyId,
    List<Member>? members,
    LabelAssignments? labels,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    bool? isAutoSingleton,
  }) {
    return Family(
      id: id ?? this.id,
      displayName: (displayName ?? this.displayName).trim(),
      canonicalName: (canonicalName ?? this.canonicalName).trim(),
      mergedIntoFamilyId: mergedIntoFamilyId ?? this.mergedIntoFamilyId,
      members: members ?? this.members,
      labels: labels ?? this.labels,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      isAutoSingleton: isAutoSingleton ?? this.isAutoSingleton,
    );
  }

  factory Family.fromJson(Map<String, dynamic> json) {
    final membersJson = json['members'] as List<dynamic>? ?? [];
    final members = membersJson
        .map((member) => Member.fromJson(member as Map<String, dynamic>))
        .toList();
    final displayName = (json['displayName'] as String).trim();
    // Migration: pre-existing families lack the flag; infer it as
    // "singleton whose family name matches the lone member's name".
    final isAutoSingleton = json['isAutoSingleton'] as bool? ??
        (members.length == 1 &&
            members.first.displayName.trim() == displayName);
    return Family(
      id: json['id'] as String,
      displayName: displayName,
      canonicalName: (json['canonicalName'] as String?)?.trim(),
      mergedIntoFamilyId: json['mergedIntoFamilyId'] as String?,
      members: members,
      labels: LabelAssignments.fromJson(
        json['labels'] as Map<String, dynamic>?,
      ),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
      isAutoSingleton: isAutoSingleton,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'canonicalName': canonicalName,
      'mergedIntoFamilyId': mergedIntoFamilyId,
      'members': members.map((member) => member.toJson()).toList(),
      'labels': labels.toJson(),
      'updatedAt': updatedAt.toIso8601String(),
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      'isAutoSingleton': isAutoSingleton,
    };
  }
}
