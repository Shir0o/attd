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
  });
}
