import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('pr-title-lint workflow allows every conventional type release-please emits',
      () {
    final configFile = File('release-please-config.json');
    if (!configFile.existsSync()) {
      fail('release-please-config.json missing at repo root.');
    }

    final config =
        jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
    final sections = (config['changelogSections'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final releasePleaseTypes = sections.map((s) => s['type'] as String).toSet();

    final workflowFile = File('.github/workflows/pr-title-lint.yml');
    expect(workflowFile.existsSync(), isTrue);
    final workflow = loadYaml(workflowFile.readAsStringSync()) as YamlMap;
    final steps = workflow['jobs']['lint']['steps'] as YamlList;
    final withBlock = steps
        .firstWhere((s) => (s['with'] as YamlMap).containsKey('types'))['with']
        as YamlMap;
    final typesField = withBlock['types'] as String;

    final lintTypes = typesField
        .split('\n')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet();

    // release-please also recognizes `revert` automatically; ensure the
    // lint allow-list covers it so revert PR titles aren't rejected.
    final allRequired = {...releasePleaseTypes, 'revert'};

    expect(
      lintTypes.containsAll(allRequired),
      isTrue,
      reason:
          'pr-title-lint must allow every type in release-please-config.json '
          'changelogSections (plus `revert`). Missing: '
          '${allRequired.difference(lintTypes)}',
    );
  });

  test('pr-title-lint workflow only runs on PRs targeting main', () {
    final workflowFile = File('.github/workflows/pr-title-lint.yml');
    final workflow = loadYaml(workflowFile.readAsStringSync()) as YamlMap;
    final pullRequest = workflow['on']['pull_request'] as YamlMap;
    final branches = (pullRequest['branches'] as YamlList)
        .map((b) => b as String)
        .toList();
    expect(branches, ['main']);
  });
}
