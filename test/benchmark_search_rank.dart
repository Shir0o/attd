import 'package:attendance_tracker/features/attendance/domain/active_roster_index.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';

void main() {
  final members = List.generate(
    1000,
    (i) => Member(
      id: 'm_$i',
      displayName: 'Member $i Firstname Lastname${i % 10}',
    ),
  );

  final families = List.generate(
    100,
    (i) => Family(
      id: 'f_$i',
      displayName: 'Family $i Smithson',
      members: members.sublist(i * 10, (i + 1) * 10),
    ),
  );

  final index = ActiveRosterIndex(members: members, families: families);

  final queries = ['mem', 'first', 'smith', 'last5', 'nonexistent'];

  final swSearch = Stopwatch()..start();
  for (var i = 0; i < 500; i++) {
    for (final q in queries) {
      index.search(q);
    }
  }
  swSearch.stop();

  final swGrouped = Stopwatch()..start();
  for (var i = 0; i < 500; i++) {
    for (final q in queries) {
      index.groupedByFamily(query: q);
    }
  }
  swGrouped.stop();

  print(
      'Search: ${swSearch.elapsedMilliseconds} ms (${swSearch.elapsedMicroseconds / 2500} us/op)');
  print(
      'GroupedByFamily: ${swGrouped.elapsedMilliseconds} ms (${swGrouped.elapsedMicroseconds / 2500} us/op)');
}
