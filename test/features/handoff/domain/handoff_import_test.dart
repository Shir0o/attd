import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/handoff/domain/handoff_file.dart';
import 'package:attendance_tracker/features/handoff/domain/handoff_import.dart';
import 'package:attendance_tracker/features/handoff/domain/mark_merge.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 11, 15, 10);

SessionRecord _rec(
  String? id,
  String name,
  AttendanceStatus status,
  DateTime at, {
  String by = 'Owner',
}) =>
    SessionRecord(
      memberId: id,
      attendee: name,
      status: status,
      recordedAt: at,
      recordedBy: by,
    );

HandoffResult _result({
  List<HandoffMark> marks = const [],
  List<HandoffGuest> guests = const [],
  String? helper = 'Sam',
}) =>
    HandoffResult(
      eventId: 'ev-1',
      sessionDate: DateTime(2026, 11, 15),
      helperName: helper,
      marks: marks,
      guests: guests,
    );

HandoffMark _mark(String id, String name, AttendanceStatus s, DateTime at) =>
    HandoffMark(memberId: id, name: name, status: s, recordedAt: at);

void main() {
  group('MarkMerge', () {
    test('present beats absent regardless of time', () {
      final present = _rec('m1', 'A', AttendanceStatus.present, _t0);
      final absent = _rec(
        'm1',
        'A',
        AttendanceStatus.absent,
        _t0.add(const Duration(hours: 1)),
      );
      expect(MarkMerge.mergeRecords(present, absent), same(present));
      expect(MarkMerge.mergeRecords(absent, present), same(present));
    });

    test('same status: the later mark wins, ties keep the first', () {
      final early = _rec('m1', 'A', AttendanceStatus.absent, _t0);
      final late = _rec(
        'm1',
        'A',
        AttendanceStatus.absent,
        _t0.add(const Duration(minutes: 5)),
      );
      expect(MarkMerge.mergeRecords(early, late), same(late));
      expect(MarkMerge.mergeRecords(late, early), same(late));
      final tie = _rec('m1', 'A', AttendanceStatus.absent, _t0);
      expect(MarkMerge.mergeRecords(early, tie), same(early));
    });

    test('mergeRecordLists keys members by id and guests by name', () {
      final local = [
        _rec('m1', 'A', AttendanceStatus.absent, _t0),
        _rec(null, 'Vic', AttendanceStatus.present, _t0),
      ];
      final incoming = [
        _rec('m1', 'A', AttendanceStatus.present, _t0),
        _rec(null, 'Vic', AttendanceStatus.present, _t0),
        _rec(null, 'Una', AttendanceStatus.present, _t0),
        _rec('m2', 'B', AttendanceStatus.absent, _t0),
      ];
      final merged = MarkMerge.mergeRecordLists(local, incoming);
      expect(merged.map(MarkMerge.recordKey), [
        'm1',
        'guest:Vic',
        'guest:Una',
        'm2',
      ]);
      expect(merged.first.status, AttendanceStatus.present);
      expect(merged[1], same(local[1]));
    });
  });

  group('HandoffImport.plan', () {
    test('creates records with the helper as actor and the owner name', () {
      final plan = HandoffImport.plan(
        result: _result(
          marks: [
            _mark('m1', 'Alice (helper copy)', AttendanceStatus.present, _t0),
            _mark('m2', 'Bob', AttendanceStatus.absent, _t0),
          ],
          guests: [HandoffGuest(name: 'Vic', recordedAt: _t0)],
        ),
        knownMembers: {'m1': 'Alice Johnson', 'm2': 'Bob Smith'},
        existing: const [],
      );
      expect(plan.changed, isTrue);
      expect(plan.unknownMemberMarks, 0);
      expect(plan.records.map((r) => r.attendee), [
        'Alice Johnson',
        'Bob Smith',
        'Vic',
      ]);
      expect(plan.records.every((r) => r.recordedBy == 'Sam'), isTrue);
      expect(plan.records.last.memberId, isNull);
    });

    test('actor falls back to Helper without a name', () {
      final plan = HandoffImport.plan(
        result: _result(
          helper: null,
          guests: [HandoffGuest(name: 'Vic', recordedAt: _t0)],
        ),
        knownMembers: const {},
        existing: const [],
      );
      expect(plan.records.single.recordedBy, 'Helper');
    });

    test('an unknown present member becomes a guest by name, not dropped', () {
      final plan = HandoffImport.plan(
        result: _result(
          marks: [_mark('gone', 'Gone Greg', AttendanceStatus.present, _t0)],
        ),
        knownMembers: const {'m1': 'Alice'},
        existing: const [],
      );
      expect(plan.unknownMemberMarks, 1);
      final record = plan.records.single;
      expect(record.memberId, isNull);
      expect(record.attendee, 'Gone Greg');
      expect(record.status, AttendanceStatus.present);
    });

    test('an unknown absent member says nothing worth keeping', () {
      final plan = HandoffImport.plan(
        result: _result(
          marks: [_mark('gone', 'Gone Greg', AttendanceStatus.absent, _t0)],
        ),
        knownMembers: const {},
        existing: const [],
      );
      expect(plan.records, isEmpty);
      expect(plan.changed, isFalse);
    });

    test('present beats an existing absent; existing present is kept', () {
      final existing = [
        _rec('m1', 'Alice', AttendanceStatus.absent, _t0),
        _rec('m2', 'Bob', AttendanceStatus.present, _t0),
      ];
      final plan = HandoffImport.plan(
        result: _result(
          marks: [
            _mark('m1', 'Alice', AttendanceStatus.present, _t0),
            _mark(
              'm2',
              'Bob',
              AttendanceStatus.absent,
              _t0.add(const Duration(hours: 2)),
            ),
          ],
        ),
        knownMembers: {'m1': 'Alice', 'm2': 'Bob'},
        existing: existing,
      );
      expect(plan.records[0].status, AttendanceStatus.present);
      expect(plan.records[0].recordedBy, 'Sam');
      expect(plan.records[1], same(existing[1]));
      expect(plan.changed, isTrue);
    });

    test('importing the same result twice changes nothing the second time', () {
      final result = _result(
        marks: [
          _mark('m1', 'Alice', AttendanceStatus.present, _t0),
          _mark('m2', 'Bob', AttendanceStatus.absent, _t0),
          _mark('gone', 'Gone Greg', AttendanceStatus.present, _t0),
        ],
        guests: [HandoffGuest(name: 'Vic', recordedAt: _t0)],
      );
      final known = {'m1': 'Alice', 'm2': 'Bob'};
      final first = HandoffImport.plan(
        result: result,
        knownMembers: known,
        existing: const [],
      );
      final second = HandoffImport.plan(
        result: result,
        knownMembers: known,
        existing: first.records,
      );
      expect(second.changed, isFalse);
      expect(second.records, hasLength(first.records.length));
      expect(second.records, hasLength(4));
    });

    test('a later import of newer same-status marks is a change', () {
      final existing = [_rec('m1', 'Alice', AttendanceStatus.absent, _t0)];
      final plan = HandoffImport.plan(
        result: _result(
          marks: [
            _mark(
              'm1',
              'Alice',
              AttendanceStatus.absent,
              _t0.add(const Duration(minutes: 1)),
            ),
          ],
        ),
        knownMembers: {'m1': 'Alice'},
        existing: existing,
      );
      expect(plan.changed, isTrue);
    });
  });
}
