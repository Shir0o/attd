import 'package:attendance_tracker/features/attendance/models/member.dart';

void main() {
  final members = List.generate(
    1000,
    (i) => Member(id: 'm_$i', displayName: 'Member Name $i'),
  );

  const query = 'member name 50';

  // Warmup
  for (var i = 0; i < 1000; i++) {
    members
        .where((m) => m.displayName.toLowerCase().contains(query))
        .take(3)
        .toList();
    members
        .where((m) => m.displayNameLowercase.contains(query))
        .take(3)
        .toList();
  }

  final swUnoptimized = Stopwatch()..start();
  for (var i = 0; i < 5000; i++) {
    members
        .where((m) => m.displayName.toLowerCase().contains(query))
        .take(3)
        .toList();
  }
  swUnoptimized.stop();

  final swOptimized = Stopwatch()..start();
  for (var i = 0; i < 5000; i++) {
    members
        .where((m) => m.displayNameLowercase.contains(query))
        .take(3)
        .toList();
  }
  swOptimized.stop();

  print('Unoptimized: ${swUnoptimized.elapsedMilliseconds}ms');
  print('Optimized: ${swOptimized.elapsedMilliseconds}ms');
  print(
      'Speedup: ${(swUnoptimized.elapsedMilliseconds / swOptimized.elapsedMilliseconds).toStringAsFixed(2)}x');
}
