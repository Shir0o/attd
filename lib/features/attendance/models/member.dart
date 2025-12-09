import 'attendance_status.dart';

class Member {
  final String id;
  final String displayName;
  final bool isVisitor;
  final AttendanceStatus defaultStatus;

  const Member({
    required this.id,
    required this.displayName,
    this.isVisitor = false,
    this.defaultStatus = AttendanceStatus.absent,
  });

  Member copyWith({
    String? id,
    String? displayName,
    bool? isVisitor,
    AttendanceStatus? defaultStatus,
  }) {
    return Member(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      isVisitor: isVisitor ?? this.isVisitor,
      defaultStatus: defaultStatus ?? this.defaultStatus,
    );
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      isVisitor: json['isVisitor'] as bool? ?? false,
      defaultStatus: AttendanceStatus.values.firstWhere(
        (status) => status.name == json['defaultStatus'],
        orElse: () => AttendanceStatus.absent,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'isVisitor': isVisitor,
      'defaultStatus': defaultStatus.name,
    };
  }
}
