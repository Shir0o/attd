import 'member.dart';

class Family {
  final String id;
  final String displayName;
  final List<Member> members;

  const Family({
    required this.id,
    required this.displayName,
    required this.members,
  });

  Family copyWith({
    String? id,
    String? displayName,
    List<Member>? members,
  }) {
    return Family(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      members: members ?? this.members,
    );
  }

  factory Family.fromJson(Map<String, dynamic> json) {
    final membersJson = json['members'] as List<dynamic>? ?? [];
    return Family(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      members: membersJson
          .map((member) => Member.fromJson(member as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'members': members.map((member) => member.toJson()).toList(),
    };
  }
}
