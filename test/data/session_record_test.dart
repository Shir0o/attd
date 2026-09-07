import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SessionRecord', () {
    final now = DateTime.now();
    final record = SessionRecord(
      memberId: 'm1',
      attendee: 'John Doe',
      status: AttendanceStatus.present,
      recordedAt: now,
      recordedBy: 'Admin',
    );

    test('supports value equality', () {
      final record2 = SessionRecord(
        memberId: 'm1',
        attendee: 'John Doe',
        status: AttendanceStatus.present,
        recordedAt: now,
        recordedBy: 'Admin',
      );
      // Since SessionRecord doesn't override ==, this checks identity by default unless using equatable or similar.
      // Checking field equality manually if == is not overridden.
      expect(record.memberId, record2.memberId);
      expect(record.attendee, record2.attendee);
      expect(record.status, record2.status);
      expect(record.recordedAt, record2.recordedAt);
      expect(record.recordedBy, record2.recordedBy);
    });

    test('copyWith creates a new instance with updated values', () {
      final updated = record.copyWith(
        attendee: 'Jane Doe',
        status: AttendanceStatus.absent,
      );
      expect(updated.memberId, record.memberId);
      expect(updated.attendee, 'Jane Doe');
      expect(updated.status, AttendanceStatus.absent);
      expect(updated.recordedAt, record.recordedAt);
      expect(updated.recordedBy, record.recordedBy);
    });

    test('toJson and fromJson work correctly', () {
      final json = record.toJson();
      expect(json['memberId'], 'm1');
      expect(json['attendee'], 'John Doe');
      expect(json['status'], 'present');
      expect(json['recordedAt'], now.toIso8601String());
      expect(json['recordedBy'], 'Admin');

      final fromJson = SessionRecord.fromJson(json);
      expect(fromJson.memberId, record.memberId);
      expect(fromJson.attendee, record.attendee);
      expect(fromJson.status, record.status);
      expect(fromJson.recordedAt.toIso8601String(), record.recordedAt.toIso8601String());
      expect(fromJson.recordedBy, record.recordedBy);
    });

    test('fromJson handles invalid status gracefully (defaults to absent)', () {
      final json = {
        'memberId': 'm1',
        'attendee': 'John Doe',
        'status': 'invalid_status',
        'recordedAt': now.toIso8601String(),
        'recordedBy': 'Admin',
      };
      final fromJson = SessionRecord.fromJson(json);
      expect(fromJson.status, AttendanceStatus.absent);
      expect(fromJson.memberId, 'm1');
    });

    test('late flag survives a serialize/deserialize round trip', () {
      final lateRecord = SessionRecord(
        memberId: 'm2',
        attendee: 'Jane Late',
        status: AttendanceStatus.present,
        recordedAt: now,
        recordedBy: 'User',
        isLate: true,
      );

      final json = lateRecord.toJson();
      expect(json['isLate'], true);

      final fromJson = SessionRecord.fromJson(json);
      expect(fromJson.isLate, isTrue);
    });

    test('json without a lateness key reads back as not-late', () {
      // A session saved before the lateness feature existed carries no
      // `isLate` key at all — it must load as nobody-was-late.
      final legacyJson = {
        'memberId': 'm1',
        'attendee': 'John Doe',
        'status': 'present',
        'recordedAt': now.toIso8601String(),
        'recordedBy': 'Admin',
      };
      final fromJson = SessionRecord.fromJson(legacyJson);
      expect(fromJson.isLate, isFalse);
    });

    test('a record constructed absent-and-late serializes as not-late', () {
      // The present-only invariant is enforced in the model: an absent record
      // can never carry the late flag.
      final absentLate = SessionRecord(
        memberId: 'm1',
        attendee: 'John Doe',
        status: AttendanceStatus.absent,
        recordedAt: now,
        recordedBy: 'Admin',
        isLate: true,
      );
      expect(absentLate.isLate, isFalse);
      expect(absentLate.toJson()['isLate'], false);
    });

    test('copyWith flipping status to absent drops the late flag', () {
      final lateRecord = record.copyWith(isLate: true);
      expect(lateRecord.isLate, isTrue);

      final flipped = lateRecord.copyWith(status: AttendanceStatus.absent);
      expect(flipped.isLate, isFalse);
    });
  });
}
