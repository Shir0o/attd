import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';

void main() {
  test(
      'Benchmark AddMemberSheet search matching: cached vs on-the-fly toLowerCase',
      () {
    final members = List.generate(
      1000,
      (i) => Member(
        id: 'm_$i',
        displayName: 'Member $i Firstname Surname${i % 10}',
      ),
    );

    final queries = ['mem', 'sur', 'john', '10', '99', 'a', 'first'];

    // Warmup
    for (final q in queries) {
      members
          .where((m) => m.displayName.toLowerCase().contains(q))
          .take(3)
          .toList();
      members.where((m) => m.displayNameLowercase.contains(q)).take(3).toList();
    }

    const iterations = 1000;

    final swUnoptimized = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      for (final q in queries) {
        members
            .where((m) => m.displayName.toLowerCase().contains(q))
            .take(3)
            .toList();
      }
    }
    swUnoptimized.stop();

    final swOptimized = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      for (final q in queries) {
        members
            .where((m) => m.displayNameLowercase.contains(q))
            .take(3)
            .toList();
      }
    }
    swOptimized.stop();

    final unoptMs = swUnoptimized.elapsedMicroseconds / 1000.0;
    final optMs = swOptimized.elapsedMicroseconds / 1000.0;
    final speedup = unoptMs / optMs;

    print(
        'Unoptimized (on-the-fly toLowerCase): ${unoptMs.toStringAsFixed(2)} ms');
    print(
        'Optimized (cached displayNameLowercase): ${optMs.toStringAsFixed(2)} ms');
    print('Speedup: ${speedup.toStringAsFixed(2)}x faster');

    expect(optMs, lessThan(unoptMs));
  });
}
