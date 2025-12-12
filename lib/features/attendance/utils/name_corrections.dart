import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';

List<Family> applyNameCorrection({
  required List<Family> families,
  required String subject,
  String? correctedName,
  List<String> duplicateCandidates = const [],
}) {
  if (correctedName == null && duplicateCandidates.isEmpty) {
    return families;
  }

  final targets = <String>{...duplicateCandidates, subject}
    ..removeWhere((name) => name.isEmpty);

  if (targets.isEmpty || correctedName == null) {
    return families;
  }

  return families.map((family) {
    var updatedFamily = family;

    if (targets.contains(family.displayName)) {
      updatedFamily = updatedFamily.copyWith(displayName: correctedName);
    }

    final updatedMembers = family.members.map((member) {
      if (targets.contains(member.displayName)) {
        return member.copyWith(displayName: correctedName);
      }
      return member;
    }).toList();

    if (!_membersMatch(updatedMembers, family.members)) {
      updatedFamily = updatedFamily.copyWith(members: updatedMembers);
    }

    return updatedFamily;
  }).toList();
}

bool _membersMatch(List<Member> next, List<Member> previous) {
  if (identical(next, previous)) return true;
  if (next.length != previous.length) return false;

  for (var i = 0; i < next.length; i++) {
    final a = next[i];
    final b = previous[i];
    if (a.id != b.id ||
        a.displayName != b.displayName ||
        a.isVisitor != b.isVisitor ||
        a.defaultStatus != b.defaultStatus) {
      return false;
    }
  }

  return true;
}
