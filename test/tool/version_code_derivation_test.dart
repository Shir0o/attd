import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Derives the same value the bash block in release.yml produces:
///   versionCode = major*10000 + minor*100 + patch
/// (tag may include a leading 'v' and an optional `-rcN`/`-betaN` suffix)
int deriveVersionCode(String tag) {
  var ver = tag;
  if (ver.startsWith('v')) ver = ver.substring(1);
  final dash = ver.indexOf('-');
  if (dash != -1) ver = ver.substring(0, dash);
  final parts = ver.split('.');
  if (parts.length != 3) {
    throw FormatException('Tag "$tag" is not a valid X.Y.Z semver');
  }
  final major = int.parse(parts[0]);
  final minor = int.parse(parts[1]);
  final patch = int.parse(parts[2]);
  return major * 10000 + minor * 100 + patch;
}

void main() {
  group('versionCode derivation', () {
    test('parses a bare semver tag', () {
      expect(deriveVersionCode('v1.3.2'), 10302);
    });

    test('parses a tag without the leading v', () {
      expect(deriveVersionCode('1.3.2'), 10302);
    });

    test('parses a pre-release tag (rc suffix)', () {
      expect(deriveVersionCode('v1.4.0-rc1'), 10400);
    });

    test('parses a pre-release tag (beta suffix)', () {
      expect(deriveVersionCode('v2.0.0-beta2'), 20000);
    });

    test('strictly monotonic across patch increments', () {
      final tags = ['v1.3.2', 'v1.3.3', 'v1.3.4'];
      final codes = tags.map(deriveVersionCode).toList();
      expect(codes, [10302, 10303, 10304]);
    });

    test('strictly monotonic across minor and major bumps', () {
      final codes = ['v1.3.2', 'v1.4.0', 'v2.0.0', 'v10.0.0']
          .map(deriveVersionCode)
          .toList();
      expect(codes, [10302, 10400, 20000, 100000]);
    });

    test('rejects malformed tags', () {
      expect(() => deriveVersionCode('not-a-tag'), throwsFormatException);
      expect(() => deriveVersionCode('v1.3'), throwsFormatException);
      expect(() => deriveVersionCode('v1.3.2.4'), throwsFormatException);
    });
  });

  group('release.yml uses the same derivation', () {
    test('the bash block in release.yml implements the same formula', () {
      final f = File('.github/workflows/release.yml');
      expect(f.existsSync(), isTrue);
      final workflow = loadYaml(f.readAsStringSync()) as YamlMap;
      final steps =
          (workflow['jobs']['build-and-publish']['steps'] as YamlList).cast<YamlMap>();
      final vcStep = steps.firstWhere(
        (s) => s['id'] == 'vc',
        orElse: () => YamlMap(),
      );
      expect(vcStep, isNot(YamlMap()),
          reason: 'release.yml must include a step with id=vc');

      final run = vcStep['run'] as String;
      // Pin the exact formula — if release.yml drifts from major*10000
      // + minor*100 + patch, this test fails.
      expect(run, contains('10#\$major * 10000 + 10#\$minor * 100 + 10#\$patch'));
    });

    test('build commands pass --build-number from the vc step', () {
      final f = File('.github/workflows/release.yml');
      final workflow = loadYaml(f.readAsStringSync()) as YamlMap;
      final steps =
          (workflow['jobs']['build-and-publish']['steps'] as YamlList).cast<YamlMap>();
      final flutterBuildSteps = steps
          .where((s) => s['run'] is String &&
              (s['run'] as String).contains('flutter build') &&
              !(s['run'] as String).contains('--debug'))
          .toList();
      for (final step in flutterBuildSteps) {
        final run = step['run'] as String;
        expect(run, contains('--build-number='),
            reason: 'flutter build step missing --build-number: $run');
        expect(run, contains('steps.vc.outputs.code'),
            reason: 'flutter build step not wired to vc step: $run');
      }
    });
  });
}