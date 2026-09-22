import 'package:attendance_tracker/features/attendance/models/label_assignments.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('combines automatic and manual labels', () {
    const assignments = LabelAssignments(
      autoLabels: {'new'},
      manualLabels: {'follow-up'},
    );

    expect(assignments.all, {'new', 'follow-up'});
    expect(assignments.hasLabel('new'), isTrue);
    expect(assignments.hasLabel('follow-up'), isTrue);
    expect(assignments.hasLabel('missing'), isFalse);
    expect(assignments.isManual('follow-up'), isTrue);
    expect(assignments.isManual('new'), isFalse);
  });

  test('parses null, legacy, and malformed json values', () {
    expect(LabelAssignments.fromJson(null).all, isEmpty);

    final legacy = LabelAssignments.fromJson({
      'labels': ['returning', 7],
      'manualLabels': 'not a list',
    });

    expect(legacy.autoLabels, {'returning', '7'});
    expect(legacy.manualLabels, isEmpty);
  });

  test('serializes automatic and manual labels separately', () {
    const assignments = LabelAssignments(
      autoLabels: {'new'},
      manualLabels: {'follow-up'},
    );

    expect(assignments.toJson(), {
      'autoLabels': ['new'],
      'manualLabels': ['follow-up'],
    });
  });
}
