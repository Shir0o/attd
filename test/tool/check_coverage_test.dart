import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('passes when LCOV line coverage meets the threshold', () async {
    final lcovFile = await _writeLcov('''
SF:lib/a.dart
LF:10
LH:7
end_of_record
''');

    final result = await _runCoverageCheck([
      '--lcov',
      lcovFile.path,
      '--min',
      '70',
    ]);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('Line coverage: 70.00% (7/10)'));
  });

  test('fails when LCOV line coverage is below the threshold', () async {
    final lcovFile = await _writeLcov('''
SF:lib/a.dart
LF:10
LH:6
end_of_record
''');

    final result = await _runCoverageCheck([
      '--lcov',
      lcovFile.path,
      '--min',
      '70',
    ]);

    expect(result.exitCode, 1);
    expect(result.stdout, contains('Line coverage: 60.00% (6/10)'));
    expect(result.stderr, contains('Coverage is below'));
  });

  test('reports missing option values', () async {
    final result = await _runCoverageCheck(['--min']);

    expect(result.exitCode, 2);
    expect(result.stderr, contains('Missing value for --min.'));
  });

  test('ignores malformed LCOV totals while summing valid lines', () async {
    final lcovFile = await _writeLcov('''
SF:lib/a.dart
LF:not-a-number
LH:ignored
LF:8
LH:4
end_of_record
''');

    final result = await _runCoverageCheck([
      '--lcov=${lcovFile.path}',
      '--min=50',
    ]);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('Line coverage: 50.00% (4/8)'));
  });
}

Future<File> _writeLcov(String contents) async {
  final directory =
      await Directory.systemTemp.createTemp('attd_coverage_test_');
  final file = File('${directory.path}/lcov.info');
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
  return file.writeAsString(contents);
}

Future<ProcessResult> _runCoverageCheck(List<String> args) {
  return Process.run(
    'dart',
    ['run', 'tool/check_coverage.dart', ...args],
    workingDirectory: Directory.current.path,
  );
}
