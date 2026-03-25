import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';

void main() {
  group('Family Model', () {
    test('fromJson sets updatedAt when present', () {
      final json = {
        'id': 'f1',
        'displayName': 'Smith',
        'members': [],
        'updatedAt': '2025-03-25T10:00:00.000Z',
      };
      final family = Family.fromJson(json);
      expect(family.updatedAt, DateTime.parse('2025-03-25T10:00:00.000Z'));
    });

    test('fromJson defaults updatedAt to epoch when missing', () {
      final json = {
        'id': 'f1',
        'displayName': 'Smith',
        'members': [],
      };
      final family = Family.fromJson(json);
      expect(family.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('fromJson parses deletedAt when present', () {
      final json = {
        'id': 'f1',
        'displayName': 'Smith',
        'members': [],
        'deletedAt': '2025-03-25T12:00:00.000Z',
      };
      final family = Family.fromJson(json);
      expect(family.deletedAt, DateTime.parse('2025-03-25T12:00:00.000Z'));
    });

    test('fromJson sets deletedAt to null when missing', () {
      final json = {
        'id': 'f1',
        'displayName': 'Smith',
        'members': [],
      };
      final family = Family.fromJson(json);
      expect(family.deletedAt, isNull);
    });

    test('toJson includes updatedAt and excludes null deletedAt', () {
      final family = Family(
        id: 'f1',
        displayName: 'Smith',
        members: [],
        updatedAt: DateTime.parse('2025-03-25T10:00:00.000Z'),
      );
      final json = family.toJson();
      expect(json['updatedAt'], '2025-03-25T10:00:00.000Z');
      expect(json.containsKey('deletedAt'), false);
    });

    test('toJson includes deletedAt when set', () {
      final family = Family(
        id: 'f1',
        displayName: 'Smith',
        members: [],
        deletedAt: DateTime.parse('2025-03-25T12:00:00.000Z'),
      );
      final json = family.toJson();
      expect(json['deletedAt'], '2025-03-25T12:00:00.000Z');
    });

    test('round-trip JSON serialization preserves all fields', () {
      final original = Family(
        id: 'f1',
        displayName: 'Smith',
        members: [
          Member(
            id: 'm1',
            displayName: 'John',
            updatedAt: DateTime.parse('2025-01-01T00:00:00.000Z'),
          ),
        ],
        updatedAt: DateTime.parse('2025-03-25T10:00:00.000Z'),
        deletedAt: DateTime.parse('2025-03-25T12:00:00.000Z'),
      );
      final restored = Family.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.displayName, original.displayName);
      expect(restored.updatedAt, original.updatedAt);
      expect(restored.deletedAt, original.deletedAt);
      expect(restored.members.length, 1);
    });

    test('copyWith updates updatedAt', () {
      final family = Family(
        id: 'f1',
        displayName: 'Smith',
        members: [],
        updatedAt: DateTime.parse('2025-01-01T00:00:00.000Z'),
      );
      final updated = family.copyWith(
        updatedAt: DateTime.parse('2025-06-01T00:00:00.000Z'),
      );
      expect(updated.updatedAt, DateTime.parse('2025-06-01T00:00:00.000Z'));
    });

    test('copyWith clearDeletedAt removes deletedAt', () {
      final family = Family(
        id: 'f1',
        displayName: 'Smith',
        members: [],
        deletedAt: DateTime.now(),
      );
      final restored = family.copyWith(clearDeletedAt: true);
      expect(restored.deletedAt, isNull);
    });
  });

  group('Member Model', () {
    test('fromJson sets updatedAt when present', () {
      final json = {
        'id': 'm1',
        'displayName': 'John',
        'updatedAt': '2025-03-25T10:00:00.000Z',
      };
      final member = Member.fromJson(json);
      expect(member.updatedAt, DateTime.parse('2025-03-25T10:00:00.000Z'));
    });

    test('fromJson defaults updatedAt to epoch when missing', () {
      final json = {
        'id': 'm1',
        'displayName': 'John',
      };
      final member = Member.fromJson(json);
      expect(member.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('fromJson parses deletedAt when present', () {
      final json = {
        'id': 'm1',
        'displayName': 'John',
        'deletedAt': '2025-03-25T12:00:00.000Z',
      };
      final member = Member.fromJson(json);
      expect(member.deletedAt, DateTime.parse('2025-03-25T12:00:00.000Z'));
    });

    test('toJson includes updatedAt and excludes null deletedAt', () {
      final member = Member(
        id: 'm1',
        displayName: 'John',
        updatedAt: DateTime.parse('2025-03-25T10:00:00.000Z'),
      );
      final json = member.toJson();
      expect(json['updatedAt'], '2025-03-25T10:00:00.000Z');
      expect(json.containsKey('deletedAt'), false);
    });

    test('toJson includes deletedAt when set', () {
      final member = Member(
        id: 'm1',
        displayName: 'John',
        deletedAt: DateTime.parse('2025-03-25T12:00:00.000Z'),
      );
      final json = member.toJson();
      expect(json['deletedAt'], '2025-03-25T12:00:00.000Z');
    });

    test('round-trip JSON serialization preserves all fields', () {
      final original = Member(
        id: 'm1',
        displayName: 'John',
        isVisitor: true,
        updatedAt: DateTime.parse('2025-03-25T10:00:00.000Z'),
        deletedAt: DateTime.parse('2025-03-25T12:00:00.000Z'),
      );
      final restored = Member.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.displayName, original.displayName);
      expect(restored.isVisitor, true);
      expect(restored.updatedAt, original.updatedAt);
      expect(restored.deletedAt, original.deletedAt);
    });

    test('copyWith updates updatedAt and deletedAt', () {
      final member = Member(
        id: 'm1',
        displayName: 'John',
        updatedAt: DateTime.parse('2025-01-01T00:00:00.000Z'),
      );
      final deleted = member.copyWith(
        updatedAt: DateTime.parse('2025-06-01T00:00:00.000Z'),
        deletedAt: DateTime.parse('2025-06-01T00:00:00.000Z'),
      );
      expect(deleted.updatedAt, DateTime.parse('2025-06-01T00:00:00.000Z'));
      expect(deleted.deletedAt, DateTime.parse('2025-06-01T00:00:00.000Z'));
    });

    test('copyWith clearDeletedAt removes deletedAt', () {
      final member = Member(
        id: 'm1',
        displayName: 'John',
        deletedAt: DateTime.now(),
      );
      final restored = member.copyWith(clearDeletedAt: true);
      expect(restored.deletedAt, isNull);
    });
  });
}
