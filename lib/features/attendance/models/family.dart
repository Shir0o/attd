import 'label_assignments.dart';
import 'member.dart';

class Family {
  final String id;
  final String displayName;
  final String canonicalName;
  final String? mergedIntoFamilyId;
  final List<Member> members;
  final LabelAssignments labels;

  const Family({
    required this.id,
    required this.displayName,
    String? canonicalName,
    this.mergedIntoFamilyId,
    required this.members,
    LabelAssignments? labels,
  }) : canonicalName = canonicalName ?? displayName,
       labels = labels ?? const LabelAssignments();

  Family copyWith({
    String? id,
    String? displayName,
    String? canonicalName,
    String? mergedIntoFamilyId,
    List<Member>? members,
    LabelAssignments? labels,
  }) {
    return Family(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      canonicalName: canonicalName ?? this.canonicalName,
      mergedIntoFamilyId: mergedIntoFamilyId ?? this.mergedIntoFamilyId,
      members: members ?? this.members,
      labels: labels ?? this.labels,
    );
  }

  factory Family.fromJson(Map<String, dynamic> json) {
    final membersJson = json['members'] as List<dynamic>? ?? [];
    return Family(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      canonicalName: json['canonicalName'] as String?,
      mergedIntoFamilyId: json['mergedIntoFamilyId'] as String?,
      members: membersJson
          .map((member) => Member.fromJson(member as Map<String, dynamic>))
          .toList(),
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
      'mergedIntoFamilyId': mergedIntoFamilyId,
      'members': members.map((member) => member.toJson()).toList(),
      'labels': labels.toJson(),
    };
  }
}
