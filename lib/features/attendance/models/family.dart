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
  }) : displayName = displayName.trim(),
       canonicalName = (canonicalName ?? displayName).trim(),
       labels = labels ?? LabelAssignments.empty,
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
    );
  }

  factory Family.fromJson(Map<String, dynamic> json) {
    final membersJson = json['members'] as List<dynamic>? ?? [];
    return Family(
      id: json['id'] as String,
      displayName: (json['displayName'] as String).trim(),
      canonicalName: (json['canonicalName'] as String?)?.trim(),
      mergedIntoFamilyId: json['mergedIntoFamilyId'] as String?,
      members: membersJson
          .map((member) => Member.fromJson(member as Map<String, dynamic>))
          .toList(),
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
      'mergedIntoFamilyId': mergedIntoFamilyId,
      'members': members.map((member) => member.toJson()).toList(),
      'labels': labels.toJson(),
      'updatedAt': updatedAt.toIso8601String(),
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    };
  }
}
