import 'dart:async';

void main() async {
  final filesToSync = [
    'sessions.json',
    'families.json',
    'events.json',
    'sessions_history.json',
  ];

  print('--- Sequential Sync ---');
  final seqStart = DateTime.now();
  for (final fileName in filesToSync) {
    await simulateNetworkCall(fileName);
  }
  final seqEnd = DateTime.now();
  final seqDuration = seqEnd.difference(seqStart);
  print('Sequential Sync took: ${seqDuration.inMilliseconds} ms\n');

  print('--- Concurrent Sync ---');
  final conStart = DateTime.now();
  await Future.wait(filesToSync.map((fileName) async {
    await simulateNetworkCall(fileName);
  }));
  final conEnd = DateTime.now();
  final conDuration = conEnd.difference(conStart);
  print('Concurrent Sync took: ${conDuration.inMilliseconds} ms\n');

  print('Improvement: ${(seqDuration.inMilliseconds - conDuration.inMilliseconds)} ms');
  print('Speedup: ${(seqDuration.inMilliseconds / conDuration.inMilliseconds).toStringAsFixed(2)}x');
}

Future<void> simulateNetworkCall(String fileName) async {
  // Simulate network latency (e.g., 500ms)
  await Future.delayed(const Duration(milliseconds: 500));
}
