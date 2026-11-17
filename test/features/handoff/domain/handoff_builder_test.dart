import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/handoff/domain/handoff_builder.dart';
import 'package:attendance_tracker/features/handoff/domain/handoff_file.dart';
import 'package:flutter_test/flutter_test.dart';

SessionRecord _rec(
  String? id,
  String name,
  AttendanceStatus status, {
  DateTime? at,
}) =>
    SessionRecord(
      memberId: id,
      attendee: name,
      status: status,
      recordedAt: at ?? DateTime.utc(2026, 11, 15, 10),
      recordedBy: 'Helper',
    );

void main() {
  group('buildHandoff', () {
    test('keeps id and name only, date-only', () {
      final doc = HandoffBuilder.buildHandoff(
        eventId: 'ev-1',
        eventTitle: 'Sunday Service',
        sessionDate: DateTime(2026, 11, 15, 9, 30),
        roster: [(id: 'm1', name: 'Alice'), (id: 'm2', name: 'Bob')],
      );
      expect(doc.eventId, 'ev-1');
      expect(doc.sessionDate, DateTime(2026, 11, 15));
      expect(doc.roster.map((p) => '${p.id}:${p.name}'), ['m1:Alice', 'm2:Bob']);
    });

    test('drops blank names and repeated ids, cleans and truncates text', () {
      final doc = HandoffBuilder.buildHandoff(
        eventId: 'ev-1',
        eventTitle: '  Sunday\n  Service  ',
        sessionDate: DateTime(2026, 11, 15),
        roster: [
          (id: 'm1', name: '  Alice\u202E  Jo\n'),
          (id: 'm2', name: '   '),
          (id: 'm1', name: 'Again'),
          (id: 'm3', name: 'x' * 300),
        ],
      );
      expect(doc.eventTitle, 'Sunday Service');
      expect(doc.roster, hasLength(2));
      expect(doc.roster.first.name, 'Alice Jo');
      expect(doc.roster.last.name.length, HandoffLimits.maxNameLength);
      // Whatever the builder makes must be encodable.
      expect(() => HandoffCodec.encode(doc), returnsNormally);
    });
  });

  group('buildResult', () {
    test('strips the handoff prefix and sends guests by name', () {
      final result = HandoffBuilder.buildResult(
        eventId: 'ev-1',
        sessionDate: DateTime(2026, 11, 15, 8),
        helperName: ' Sam ',
        records: [
          _rec('handoff:m1', 'Alice', AttendanceStatus.present),
          _rec('handoff:m2', 'Bob', AttendanceStatus.absent),
          _rec(null, 'Visitor Vic', AttendanceStatus.present),
        ],
      );
      expect(result.helperName, 'Sam');
      expect(result.sessionDate, DateTime(2026, 11, 15));
      expect(result.marks.map((m) => m.memberId), ['m1', 'm2']);
      expect(result.marks.last.status, AttendanceStatus.absent);
      expect(result.guests.single.name, 'Visitor Vic');
      expect(() => HandoffCodec.encode(result), returnsNormally);
    });

    test('never leaks an unprefixed local id; sends it as a guest by name', () {
      final result = HandoffBuilder.buildResult(
        eventId: 'ev-1',
        sessionDate: DateTime(2026, 11, 15),
        records: [
          _rec('local-uuid', 'Local Person', AttendanceStatus.present),
          _rec('local-uuid-2', 'Local Absent', AttendanceStatus.absent),
        ],
      );
      expect(result.marks, isEmpty);
      expect(result.guests.single.name, 'Local Person');
    });

    test('drops blank names and treats a blank helper name as none', () {
      final result = HandoffBuilder.buildResult(
        eventId: 'ev-1',
        sessionDate: DateTime(2026, 11, 15),
        helperName: '   ',
        records: [_rec('handoff:m1', '  ', AttendanceStatus.present)],
      );
      expect(result.helperName, isNull);
      expect(result.marks, isEmpty);
      expect(
        HandoffBuilder.buildResult(
          eventId: 'ev-1',
          sessionDate: DateTime(2026, 11, 15),
          records: const [],
        ).helperName,
        isNull,
      );
    });
  });
}
