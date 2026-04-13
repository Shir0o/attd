import 'dart:async';
import 'package:attendance_tracker/data/local_session_repository.dart';
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'dart:io';

class Benchmark {
  static Future<void> run() async {
    final tempDir = Directory.systemTemp.createTempSync('benchmark_sessions');
    try {
      final repository = LocalJsonSessionRepository(storagePath: tempDir.path);

      // Create many sessions to make it slow
      print('Creating 2000 sessions...');
      final now = DateTime.now();
      final sessions = List.generate(2000, (i) => Session(
        id: 'session_$i',
        title: 'Session $i',
        sessionDate: now.subtract(Duration(minutes: i)),
        records: [],
        createdAt: now,
        updatedAt: now,
        createdBy: 'benchmark',
      ));

      // Manually inject into cache to avoid file I/O during benchmark
      // We need to use reflection or just call a method that sets it.
      // loadSessions with many sessions in file.

      final file = File('${tempDir.path}/sessions.json');
      final jsonContent = '[' + sessions.map((s) => '{"id":"${s.id}","title":"${s.title}","sessionDate":"${s.sessionDate.toIso8601String()}","records":[],"createdAt":"${s.createdAt.toIso8601String()}","updatedAt":"${s.updatedAt.toIso8601String()}","createdBy":"benchmark","currentVersion":1}').join(',') + ']';
      await file.writeAsString(jsonContent);

      await repository.loadSessions(); // Warm up and load into cache

      final stopwatch = Stopwatch()..start();
      const iterations = 1000;
      for (var i = 0; i < iterations; i++) {
        await repository.loadSessions();
      }
      stopwatch.stop();

      print('loadSessions (cache hit) x$iterations: ${stopwatch.elapsedMilliseconds}ms');
      print('Average: ${stopwatch.elapsedMilliseconds / iterations}ms per call');

    } finally {
      tempDir.deleteSync(recursive: true);
    }
  }
}

void main() async {
  await Benchmark.run();
}
