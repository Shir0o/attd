import 'dart:async';

Future<void> mockApiCall(String id) async {
  // Simulate network latency (e.g., 200ms)
  await Future.delayed(const Duration(milliseconds: 200));
}

Future<void> sequentialProcessing(List<String> ids) async {
  for (final id in ids) {
    try {
      await mockApiCall(id);
    } catch (e) {
      // ignore
    }
  }
}

Future<void> concurrentProcessing(List<String> ids) async {
  await Future.wait(ids.map((id) async {
    try {
      await mockApiCall(id);
    } catch (e) {
      // ignore
    }
  }));
}

void main() async {
  final ids = List.generate(10, (index) => 'id_$index');

  print('Starting Sequential Processing of ${ids.length} items...');
  final stopwatchSeq = Stopwatch()..start();
  await sequentialProcessing(ids);
  stopwatchSeq.stop();
  final seqTime = stopwatchSeq.elapsedMilliseconds;
  print('Sequential time: ${seqTime}ms');

  print('Starting Concurrent Processing of ${ids.length} items...');
  final stopwatchCon = Stopwatch()..start();
  await concurrentProcessing(ids);
  stopwatchCon.stop();
  final conTime = stopwatchCon.elapsedMilliseconds;
  print('Concurrent time: ${conTime}ms');

  final improvement = ((seqTime - conTime) / seqTime * 100).toStringAsFixed(2);
  print('Simulated Improvement: $improvement%');
}
