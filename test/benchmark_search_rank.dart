import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/attendance/domain/active_roster_index.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';

void main() {
  test('Benchmark ActiveRosterIndex search performance', () {
    final members = List.generate(
      1000,
      (i) => Member(
        id: 'm_$i',
        displayName: 'Member $i Firstname Surname${i % 10}',
      ),
    );

    final families = List.generate(
      100,
      (i) => Family(
        id: 'f_$i',
        displayName: 'Family $i',
        members: members.sublist(i * 10, (i + 1) * 10),
      ),
    );

    final index = ActiveRosterIndex(
      members: members,
      families: families,
    );

    final queries = ['mem', 'sur', 'fam', 'john', '10', '99', 'a', 'first'];

    // Warmup
    for (final q in queries) {
      index.search(q);
      index.groupedByFamily(query: q);
    }

    final sw = Stopwatch()..start();
    const iterations = 1000;
    for (var i = 0; i < iterations; i++) {
      for (final q in queries) {
        index.search(q);
        index.groupedByFamily(query: q);
      }
    }
    sw.stop();

    print(
      'Time taken for ${iterations * queries.length} searches and family group lookups: ${sw.elapsedMicroseconds / 1000.0} ms',
    );
  });
}
