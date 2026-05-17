import 'dart:io';

const _defaultLcovPath = 'coverage/lcov.info';
const _defaultMinCoverage = 66.9;

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final lcovPath = _optionValue(args, '--lcov', _defaultLcovPath);
  final minCoverageText = _optionValue(args, '--min');
  if (exitCode != 0) {
    return;
  }

  final minCoverage = minCoverageText == null
      ? _defaultMinCoverage
      : double.tryParse(minCoverageText);

  if (minCoverage == null) {
    stderr.writeln('Invalid --min value: $minCoverageText');
    exitCode = 2;
    return;
  }

  final lcovFile = File(lcovPath!);
  if (!lcovFile.existsSync()) {
    stderr.writeln('Coverage file not found: $lcovPath');
    stderr.writeln('Run `flutter test --coverage` first.');
    exitCode = 2;
    return;
  }

  final totals = _readLineTotals(lcovFile);
  if (totals.found == 0) {
    stderr.writeln('No line coverage totals found in $lcovPath.');
    exitCode = 2;
    return;
  }

  final coverage = totals.hit / totals.found * 100;
  final formattedCoverage = coverage.toStringAsFixed(2);
  final formattedThreshold = minCoverage.toStringAsFixed(2);

  stdout.writeln(
    'Line coverage: $formattedCoverage% '
    '(${totals.hit}/${totals.found}), threshold: $formattedThreshold%',
  );

  if (coverage < minCoverage) {
    stderr.writeln(
      'Coverage is below the configured threshold. '
      'Add tests or lower the threshold intentionally.',
    );
    exitCode = 1;
  }
}

String? _optionValue(List<String> args, String name, [String? defaultValue]) {
  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    if (arg == name) {
      if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
        stderr.writeln('Missing value for $name.');
        exitCode = 2;
        return null;
      }
      return args[index + 1];
    }
    if (arg.startsWith('$name=')) {
      final value = arg.substring(name.length + 1);
      if (value.isEmpty) {
        stderr.writeln('Missing value for $name.');
        exitCode = 2;
        return null;
      }
      return value;
    }
  }
  return defaultValue;
}

({int found, int hit}) _readLineTotals(File lcovFile) {
  var found = 0;
  var hit = 0;

  for (final line in lcovFile.readAsLinesSync()) {
    final parts = line.split(':');
    if (parts.length < 2) {
      continue;
    }

    final key = parts[0];
    final value = int.tryParse(parts[1].trim());
    if (value == null) {
      continue;
    }

    if (key == 'LF') {
      found += value;
    } else if (key == 'LH') {
      hit += value;
    }
  }

  return (found: found, hit: hit);
}

void _printUsage() {
  stdout.writeln('''
Usage: dart run tool/check_coverage.dart [--lcov path] [--min percent]

Checks line coverage totals from an LCOV file. Defaults:
  --lcov $_defaultLcovPath
  --min  $_defaultMinCoverage
''');
}
