import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/label_assignments.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Family, Member, and LabelAssignments', () {
    const labels = LabelAssignments(
      autoLabels: {'Regular'},
      manualLabels: {'VIP'},
    );

    final member = Member(
      id: 'm1',
      displayName: 'Alice',
      defaultStatus: AttendanceStatus.present,
      labels: labels,
      isVisitor: true,
    );

    final family = Family(
      id: 'f1',
      displayName: 'Wonderland',
      members: [member],
      labels: labels,
    );

    group('LabelAssignments', () {
      test('all returns combined set', () {
        expect(labels.all, {'Regular', 'VIP'});
      });

      test('hasLabel checks both sets', () {
        expect(labels.hasLabel('Regular'), isTrue);
        expect(labels.hasLabel('VIP'), isTrue);
        expect(labels.hasLabel('None'), isFalse);
      });

      test('isManual checks manual set only', () {
        expect(labels.isManual('VIP'), isTrue);
        expect(labels.isManual('Regular'), isFalse);
      });

      test('toJson and fromJson work correctly', () {
        final json = labels.toJson();
        expect(json['autoLabels'], contains('Regular'));
        expect(json['manualLabels'], contains('VIP'));

        final fromJson = LabelAssignments.fromJson(json);
        expect(fromJson.autoLabels, {'Regular'});
        expect(fromJson.manualLabels, {'VIP'});
      });
    });

    group('Member', () {
      test('copyWith creates new instance', () {
        final updated = member.copyWith(displayName: 'Bob');
        expect(updated.displayName, 'Bob');
        expect(updated.id, 'm1');
        expect(updated.labels, labels);
      });

      test('toJson and fromJson work correctly', () {
        final json = member.toJson();
        expect(json['id'], 'm1');
        expect(json['displayName'], 'Alice');
        expect(json['isVisitor'], isTrue);
        expect(json['defaultStatus'], 'present');
        expect(json['labels'], isA<Map>());

        final fromJson = Member.fromJson(json);
        expect(fromJson.displayName, member.displayName);
        expect(fromJson.defaultStatus, member.defaultStatus);
        expect(fromJson.labels.all, member.labels.all);
      });
    });

    group('Family', () {
      test('copyWith creates new instance', () {
        final updated = family.copyWith(displayName: 'Oz');
        expect(updated.displayName, 'Oz');
        expect(updated.members.length, 1);
      });

      test('toJson and fromJson work correctly', () {
        final json = family.toJson();
        expect(json['id'], 'f1');
        expect(json['displayName'], 'Wonderland');
        expect(json['members'], isA<List>());
        expect((json['members'] as List).length, 1);

        final fromJson = Family.fromJson(json);
        expect(fromJson.id, family.id);
        expect(fromJson.members.length, 1);
        expect(fromJson.members.first.displayName, 'Alice');
      });
    });
  });
}
