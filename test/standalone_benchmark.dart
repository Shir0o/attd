import 'dart:io';

void main() {
  final now = DateTime.now();
  final list = List.generate(2000, (i) => now.subtract(Duration(minutes: i)));

  final stopwatch = Stopwatch()..start();
  const iterations = 10000;
  for (var i = 0; i < iterations; i++) {
    final copy = list.toList();
    copy.sort((a, b) => b.compareTo(a));
  }
  stopwatch.stop();

  print('Sort 2000 items x$iterations: ${stopwatch.elapsedMilliseconds}ms');
  print('Average: ${stopwatch.elapsedMilliseconds / iterations}ms per sort');
}
