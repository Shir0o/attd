import 'dart:convert';
import 'dart:typed_data';

import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/handoff/domain/handoff_file.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _handoff() => {
      'app': 'attd',
      'kind': 'handoff',
      'version': 1,
      'eventId': 'ev-1',
      'eventTitle': 'Sunday Service',
      'sessionDate': '2026-11-15',
      'roster': [
        {'id': 'm1', 'name': 'Alice Johnson'},
        {'id': 'm2', 'name': 'Bob Smith'},
      ],
    };

Map<String, Object?> _result() => {
      'app': 'attd',
      'kind': 'result',
      'version': 1,
      'eventId': 'ev-1',
      'sessionDate': '2026-11-15',
      'helperName': 'Sam',
      'marks': [
        {
          'memberId': 'm1',
          'name': 'Alice Johnson',
          'status': 'present',
          'recordedAt': '2026-11-15T10:00:00.000Z',
        },
      ],
      'guests': [
        {'name': 'Visitor Vic', 'recordedAt': '2026-11-15T10:05:00.000Z'},
      ],
    };

HandoffDocument _decode(Object? json) =>
    HandoffCodec.decodeString(jsonEncode(json));

void _rejects(Object? json, [String? messagePart]) {
  expect(
    () => _decode(json),
    throwsA(
      isA<HandoffFormatException>().having(
        (e) => e.message,
        'message',
        contains(messagePart ?? ''),
      ),
    ),
  );
}

void main() {
  group('decode handoff', () {
    test('reads a valid handoff', () {
      final doc = _decode(_handoff()) as HandoffRoster;
      expect(doc.eventId, 'ev-1');
      expect(doc.eventTitle, 'Sunday Service');
      expect(doc.sessionDate, DateTime(2026, 11, 15));
      expect(doc.roster.map((p) => p.name), ['Alice Johnson', 'Bob Smith']);
      expect(doc.localEventId, 'handoff:ev-1');
      expect(HandoffRoster.localMemberId('m1'), 'handoff:m1');
      expect(HandoffRoster.sourceMemberId('handoff:m1'), 'm1');
      expect(HandoffRoster.sourceMemberId('m1'), isNull);
    });

    test('trims names', () {
      final json = _handoff()
        ..['roster'] = [
          {'id': 'm1', 'name': '  Alice  '},
        ];
      final doc = _decode(json) as HandoffRoster;
      expect(doc.roster.single.name, 'Alice');
    });

    test('accepts an empty roster', () {
      final doc = _decode(_handoff()..['roster'] = []) as HandoffRoster;
      expect(doc.roster, isEmpty);
    });

    test('rejects a newer version with an update message', () {
      _rejects(_handoff()..['version'] = 2, 'newer version');
    });

    test('rejects missing, zero, negative and non-integer versions', () {
      _rejects(_handoff()..remove('version'));
      _rejects(_handoff()..['version'] = 0);
      _rejects(_handoff()..['version'] = -1);
      _rejects(_handoff()..['version'] = '1');
      _rejects(_handoff()..['version'] = 1.5);
    });

    test('rejects the wrong app marker or kind', () {
      _rejects(_handoff()..['app'] = 'other', 'not an Attendance Tracker');
      _rejects(_handoff()..['kind'] = 'backup', 'not an Attendance Tracker');
      _rejects(_handoff()..remove('kind'));
    });

    test('rejects extra keys at every level', () {
      _rejects(_handoff()..['extra'] = 1);
      _rejects(_handoff()
        ..['roster'] = [
          {'id': 'm1', 'name': 'A', 'phone': '555'},
        ]);
    });

    test('rejects missing keys', () {
      for (final key in ['eventId', 'eventTitle', 'sessionDate', 'roster']) {
        _rejects(_handoff()..remove(key));
      }
      _rejects(_handoff()
        ..['roster'] = [
          {'id': 'm1'},
        ]);
    });

    test('rejects wrong types', () {
      _rejects(_handoff()..['eventId'] = 5);
      _rejects(_handoff()..['eventTitle'] = ['x']);
      _rejects(_handoff()..['roster'] = 'nope');
      _rejects(_handoff()..['roster'] = ['nope']);
      _rejects(_handoff()
        ..['roster'] = [
          {'id': 1, 'name': 'A'},
        ]);
    });

    test('rejects non-object roots', () {
      _rejects([1, 2]);
      _rejects('text');
      _rejects(null);
    });

    test('rejects text that is not JSON', () {
      expect(
        () => HandoffCodec.decodeString('not json {'),
        throwsA(isA<HandoffFormatException>()),
      );
    });

    test('rejects bytes that are not UTF-8', () {
      expect(
        () => HandoffCodec.decodeBytes(Uint8List.fromList([0xff, 0xfe, 0xfd])),
        throwsA(isA<HandoffFormatException>()),
      );
    });

    test('rejects a duplicate roster id', () {
      _rejects(
        _handoff()
          ..['roster'] = [
            {'id': 'm1', 'name': 'A'},
            {'id': 'm1', 'name': 'B'},
          ],
        'same person twice',
      );
    });

    test('rejects ids that could collide, escape or inject', () {
      for (final bad in [
        '',
        'handoff:m1',
        'a/b',
        r'a\b',
        '../x',
        'a b',
        'x' * 65,
        'm1\n',
        'é',
      ]) {
        _rejects(_handoff()..['eventId'] = bad);
        _rejects(_handoff()
          ..['roster'] = [
            {'id': bad, 'name': 'A'},
          ]);
      }
    });

    test('accepts UUID-shaped ids and the maximum id length', () {
      final uuid = '123e4567-e89b-42d3-a456-426614174000';
      final doc = _decode(_handoff()..['eventId'] = uuid) as HandoffRoster;
      expect(doc.eventId, uuid);
      _decode(_handoff()..['eventId'] = 'x' * 64);
    });

    test('rejects over-long and empty strings', () {
      _rejects(_handoff()..['eventTitle'] = 'x' * 121);
      _rejects(_handoff()..['eventTitle'] = '   ');
      _rejects(_handoff()
        ..['roster'] = [
          {'id': 'm1', 'name': 'x' * 101},
        ]);
      _rejects(_handoff()
        ..['roster'] = [
          {'id': 'm1', 'name': ''},
        ]);
      _decode(_handoff()..['eventTitle'] = 'x' * 120);
    });

    test('rejects control and bidirectional override characters', () {
      for (final bad in ['A\nB', 'A\u0000B', 'A\u202EB', 'A\u0085B', 'A\u2067B']) {
        _rejects(_handoff()..['eventTitle'] = bad);
      }
    });

    test('rejects a roster over the limit but accepts the limit', () {
      List<Map<String, String>> roster(int n) => [
            for (var i = 0; i < n; i++) {'id': 'm$i', 'name': 'P$i'},
          ];
      _rejects(
        _handoff()..['roster'] = roster(HandoffLimits.maxRoster + 1),
        'too many',
      );
      final doc = _decode(_handoff()..['roster'] = roster(HandoffLimits.maxRoster))
          as HandoffRoster;
      expect(doc.roster, hasLength(HandoffLimits.maxRoster));
    });

    test('rejects bad dates', () {
      for (final bad in [
        '2026-13-01',
        '2026-02-30',
        '15-11-2026',
        '2026-11-15T00:00:00',
        '2026-1-5',
        '',
        20261115,
      ]) {
        _rejects(_handoff()..['sessionDate'] = bad);
      }
    });
  });

  group('size cap', () {
    test('rejects oversized bytes before parsing', () {
      final bytes = Uint8List(HandoffLimits.maxBytes + 1);
      expect(
        () => HandoffCodec.decodeBytes(bytes),
        throwsA(
          isA<HandoffFormatException>()
              .having((e) => e.message, 'message', contains('too large')),
        ),
      );
    });

    test('rejects an oversized string', () {
      expect(
        () => HandoffCodec.decodeString('x' * (HandoffLimits.maxBytes + 1)),
        throwsA(isA<HandoffFormatException>()),
      );
    });

    test('accepts bytes at the cap when valid', () {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(_handoff())));
      expect(HandoffCodec.decodeBytes(bytes), isA<HandoffRoster>());
    });
  });

  group('decode result', () {
    test('reads a valid result', () {
      final doc = _decode(_result()) as HandoffResult;
      expect(doc.eventId, 'ev-1');
      expect(doc.sessionDate, DateTime(2026, 11, 15));
      expect(doc.helperName, 'Sam');
      expect(doc.actor, 'Sam');
      expect(doc.marks.single.memberId, 'm1');
      expect(doc.marks.single.status, AttendanceStatus.present);
      expect(doc.marks.single.recordedAt.isUtc, isTrue);
      expect(doc.guests.single.name, 'Visitor Vic');
      expect(doc.presentCount, 1);
      expect(doc.absentCount, 0);
      expect(doc.guestCount, 1);
    });

    test('helper name is optional and the actor falls back', () {
      final doc = _decode(_result()..remove('helperName')) as HandoffResult;
      expect(doc.helperName, isNull);
      expect(doc.actor, 'Helper');
    });

    test('rejects a blank or over-long helper name', () {
      _rejects(_result()..['helperName'] = '  ');
      _rejects(_result()..['helperName'] = 'x' * 61);
      _decode(_result()..['helperName'] = 'x' * 60);
    });

    test('rejects unknown statuses including late', () {
      for (final bad in ['late', 'PRESENT', '', null, 1]) {
        _rejects(_result()
          ..['marks'] = [
            {
              'memberId': 'm1',
              'name': 'A',
              'status': bad,
              'recordedAt': '2026-11-15T10:00:00Z',
            },
          ]);
      }
    });

    test('rejects bad timestamps', () {
      for (final bad in ['yesterday', '', 5, 'x' * 41, null]) {
        _rejects(_result()
          ..['guests'] = [
            {'name': 'A', 'recordedAt': bad},
          ]);
      }
    });

    test('rejects extra and missing keys in marks and guests', () {
      _rejects(_result()
        ..['marks'] = [
          {
            'memberId': 'm1',
            'name': 'A',
            'status': 'present',
            'recordedAt': '2026-11-15T10:00:00Z',
            'isLate': true,
          },
        ]);
      _rejects(_result()
        ..['guests'] = [
          {'name': 'A'},
        ]);
      _rejects(_result()..remove('marks'));
      _rejects(_result()..remove('guests'));
    });

    test('rejects a member marked twice', () {
      final mark = {
        'memberId': 'm1',
        'name': 'A',
        'status': 'present',
        'recordedAt': '2026-11-15T10:00:00Z',
      };
      _rejects(_result()..['marks'] = [mark, mark], 'twice');
    });

    test('bounds marks and guests', () {
      _rejects(
        _result()
          ..['marks'] = [
            for (var i = 0; i <= HandoffLimits.maxMarks; i++)
              {
                'memberId': 'm$i',
                'name': 'A',
                'status': 'absent',
                'recordedAt': '2026-11-15T10:00:00Z',
              },
          ],
        'too many',
      );
      _rejects(
        _result()
          ..['guests'] = [
            for (var i = 0; i <= HandoffLimits.maxGuests; i++)
              {'name': 'G$i', 'recordedAt': '2026-11-15T10:00:00Z'},
          ],
        'too many',
      );
    });

    test('a handoff-id attempt in a result is rejected', () {
      _rejects(_result()
        ..['marks'] = [
          {
            'memberId': 'handoff:m1',
            'name': 'A',
            'status': 'present',
            'recordedAt': '2026-11-15T10:00:00Z',
          },
        ]);
    });
  });

  group('encode', () {
    test('handoff round trips and carries only the agreed fields', () {
      final doc = HandoffRoster(
        eventId: 'ev-1',
        eventTitle: 'Sunday Service',
        sessionDate: DateTime(2026, 11, 15, 9, 30),
        roster: const [HandoffPerson(id: 'm1', name: 'Alice')],
      );
      final text = HandoffCodec.encode(doc);
      final map = jsonDecode(text) as Map<String, dynamic>;
      expect(map.keys.toSet(), {
        'app',
        'kind',
        'version',
        'eventId',
        'eventTitle',
        'sessionDate',
        'roster',
      });
      expect(map['sessionDate'], '2026-11-15');
      expect((map['roster'] as List).single, {'id': 'm1', 'name': 'Alice'});
      final back = HandoffCodec.decodeString(text) as HandoffRoster;
      expect(back.roster.single.name, 'Alice');
      expect(back.sessionDate, DateTime(2026, 11, 15));
    });

    test('result round trips', () {
      final doc = HandoffResult(
        eventId: 'ev-1',
        sessionDate: DateTime(2026, 11, 15),
        helperName: 'Sam',
        marks: [
          HandoffMark(
            memberId: 'm1',
            name: 'Alice',
            status: AttendanceStatus.absent,
            recordedAt: DateTime.utc(2026, 11, 15, 10),
          ),
        ],
        guests: [
          HandoffGuest(
            name: 'Vic',
            recordedAt: DateTime.utc(2026, 11, 15, 10, 5),
          ),
        ],
      );
      final bytes = HandoffCodec.encodeBytes(doc);
      final back = HandoffCodec.decodeBytes(bytes) as HandoffResult;
      expect(back.helperName, 'Sam');
      expect(back.marks.single.status, AttendanceStatus.absent);
      expect(back.marks.single.recordedAt, DateTime.utc(2026, 11, 15, 10));
      expect(back.guests.single.name, 'Vic');
    });

    test('a result without a helper name omits the key', () {
      final doc = HandoffResult(
        eventId: 'ev-1',
        sessionDate: DateTime(2026, 11, 15),
        marks: const [],
        guests: const [],
      );
      expect(
        (jsonDecode(HandoffCodec.encode(doc)) as Map).containsKey('helperName'),
        isFalse,
      );
    });

    test('refuses to write a file the app itself would reject', () {
      final doc = HandoffRoster(
        eventId: 'bad id!',
        eventTitle: 'T',
        sessionDate: DateTime(2026, 11, 15),
        roster: const [],
      );
      expect(
        () => HandoffCodec.encode(doc),
        throwsA(isA<HandoffFormatException>()),
      );
    });

    test('exposes the file type', () {
      expect(handoffFileExtension, 'attdhandoff');
      expect(handoffMimeType, 'application/vnd.attd.handoff+json');
    });

    test('exception has a readable string form', () {
      expect(
        const HandoffFormatException('boom').toString(),
        contains('boom'),
      );
    });
  });
}
