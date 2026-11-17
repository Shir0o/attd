import 'dart:convert';
import 'dart:typed_data';

import '../../attendance/models/attendance_status.dart';

/// File extension of a handoff or result file (no leading dot).
const String handoffFileExtension = 'attdhandoff';

/// MIME type of a handoff or result file.
const String handoffMimeType = 'application/vnd.attd.handoff+json';

/// Hard bounds applied to every incoming file. Files are untrusted input.
abstract final class HandoffLimits {
  static const int maxBytes = 512 * 1024;
  static const int maxRoster = 1000;
  static const int maxMarks = 1000;
  static const int maxGuests = 500;
  static const int maxIdLength = 64;
  static const int maxNameLength = 100;
  static const int maxTitleLength = 120;
  static const int maxHelperNameLength = 60;
}

/// Ids that came out of a file live on the helper's phone under this prefix.
/// Ids this app generates are UUIDs and never contain a colon, so a file can
/// never name (and therefore never overwrite) one of the helper's own records.
const String handoffIdPrefix = 'handoff:';

/// Rejection of an incoming or outgoing file. [message] is user-presentable.
class HandoffFormatException implements Exception {
  const HandoffFormatException(this.message);

  final String message;

  @override
  String toString() => 'HandoffFormatException: $message';
}

/// One person on a handed-off roster: id and display name only.
class HandoffPerson {
  const HandoffPerson({required this.id, required this.name});

  final String id;
  final String name;
}

/// A recorded mark for a person on the handed-off roster.
class HandoffMark {
  const HandoffMark({
    required this.memberId,
    required this.name,
    required this.status,
    required this.recordedAt,
  });

  final String memberId;

  /// Carried so that a mark whose member no longer exists can still be kept
  /// as a guest mark by name. It is a name the owner already sent out.
  final String name;
  final AttendanceStatus status;
  final DateTime recordedAt;
}

/// A mark for someone who was not on the roster.
class HandoffGuest {
  const HandoffGuest({required this.name, required this.recordedAt});

  final String name;
  final DateTime recordedAt;
}

sealed class HandoffDocument {
  const HandoffDocument();
}

/// Owner to helper: one session of one event and who is expected.
class HandoffRoster extends HandoffDocument {
  const HandoffRoster({
    required this.eventId,
    required this.eventTitle,
    required this.sessionDate,
    required this.roster,
  });

  /// The owner's event id.
  final String eventId;
  final String eventTitle;

  /// Calendar day being handed off (time of day is ignored).
  final DateTime sessionDate;
  final List<HandoffPerson> roster;

  /// Id of the event on the helper's phone.
  String get localEventId => '$handoffIdPrefix$eventId';

  /// Id of a roster member on the helper's phone.
  static String localMemberId(String id) => '$handoffIdPrefix$id';

  /// Inverse of [localMemberId]; null when [localId] is not a handoff id.
  static String? sourceMemberId(String localId) =>
      localId.startsWith(handoffIdPrefix)
          ? localId.substring(handoffIdPrefix.length)
          : null;
}

/// Helper to owner: the marks recorded for one session.
class HandoffResult extends HandoffDocument {
  const HandoffResult({
    required this.eventId,
    required this.sessionDate,
    this.helperName,
    required this.marks,
    required this.guests,
  });

  /// The owner's event id.
  final String eventId;
  final DateTime sessionDate;
  final String? helperName;
  final List<HandoffMark> marks;
  final List<HandoffGuest> guests;

  /// Who the marks are attributed to.
  String get actor => helperName ?? 'Helper';

  int get presentCount =>
      marks.where((m) => m.status == AttendanceStatus.present).length;
  int get absentCount => marks.length - presentCount;
  int get guestCount => guests.length;
}

/// Reading and writing handoff files. Everything read here is untrusted: the
/// size is checked before parsing, the shape must match exactly, and nothing
/// in a file is ever used as a path, route or command.
abstract final class HandoffCodec {
  static const int version = 1;
  static const String _app = 'attd';
  static const String _kindHandoff = 'handoff';
  static const String _kindResult = 'result';

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9._-]+$');
  static final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  // C0/C1 controls and bidirectional overrides, which can disguise a name.
  static final RegExp _forbiddenText = RegExp(
    r'[\u0000-\u001F\u007F-\u009F\u202A-\u202E\u2066-\u2069]',
  );

  static String encode(HandoffDocument document) {
    final Map<String, Object?> map = switch (document) {
      HandoffRoster d => {
          'app': _app,
          'kind': _kindHandoff,
          'version': version,
          'eventId': d.eventId,
          'eventTitle': d.eventTitle,
          'sessionDate': _formatDate(d.sessionDate),
          'roster': [
            for (final p in d.roster) {'id': p.id, 'name': p.name},
          ],
        },
      HandoffResult d => {
          'app': _app,
          'kind': _kindResult,
          'version': version,
          'eventId': d.eventId,
          'sessionDate': _formatDate(d.sessionDate),
          if (d.helperName != null) 'helperName': d.helperName,
          'marks': [
            for (final m in d.marks)
              {
                'memberId': m.memberId,
                'name': m.name,
                'status': m.status.name,
                'recordedAt': m.recordedAt.toUtc().toIso8601String(),
              },
          ],
          'guests': [
            for (final g in d.guests)
              {
                'name': g.name,
                'recordedAt': g.recordedAt.toUtc().toIso8601String(),
              },
          ],
        },
    };
    final text = jsonEncode(map);
    // Whatever leaves this phone must be something this app would accept.
    decodeString(text);
    return text;
  }

  static Uint8List encodeBytes(HandoffDocument document) =>
      Uint8List.fromList(utf8.encode(encode(document)));

  /// Decodes raw file bytes. The size cap is enforced before any parsing.
  static HandoffDocument decodeBytes(Uint8List bytes) {
    if (bytes.length > HandoffLimits.maxBytes) {
      throw const HandoffFormatException(
        'This file is too large to be an Attendance Tracker handoff file.',
      );
    }
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const HandoffFormatException(
        'This is not an Attendance Tracker handoff file.',
      );
    }
    return decodeString(text);
  }

  static HandoffDocument decodeString(String text) {
    if (text.length > HandoffLimits.maxBytes) {
      throw const HandoffFormatException(
        'This file is too large to be an Attendance Tracker handoff file.',
      );
    }
    final Object? raw;
    try {
      raw = jsonDecode(text);
    } on FormatException {
      throw const HandoffFormatException(
        'This is not an Attendance Tracker handoff file.',
      );
    }
    if (raw is! Map || raw['app'] != _app) {
      throw const HandoffFormatException(
        'This is not an Attendance Tracker handoff file.',
      );
    }
    final fileVersion = raw['version'];
    if (fileVersion is! int || fileVersion < 1) {
      throw const HandoffFormatException(
        'This is not an Attendance Tracker handoff file.',
      );
    }
    if (fileVersion > version) {
      throw const HandoffFormatException(
        'This file was made by a newer version of the app. '
        'Update Attendance Tracker and try again.',
      );
    }
    switch (raw['kind']) {
      case _kindHandoff:
        return _decodeHandoff(raw);
      case _kindResult:
        return _decodeResult(raw);
      default:
        throw const HandoffFormatException(
          'This is not an Attendance Tracker handoff file.',
        );
    }
  }

  static HandoffRoster _decodeHandoff(Map raw) {
    _exactKeys(raw, const {
      'app',
      'kind',
      'version',
      'eventId',
      'eventTitle',
      'sessionDate',
      'roster',
    });
    final roster = _list(raw['roster'], HandoffLimits.maxRoster, 'roster');
    final seen = <String>{};
    final people = <HandoffPerson>[];
    for (final entry in roster) {
      final map = _map(entry, const {'id', 'name'});
      final id = _id(map['id']);
      if (!seen.add(id)) {
        throw const HandoffFormatException(
          'This handoff file lists the same person twice.',
        );
      }
      people.add(HandoffPerson(
        id: id,
        name: _text(map['name'], HandoffLimits.maxNameLength),
      ));
    }
    return HandoffRoster(
      eventId: _id(raw['eventId']),
      eventTitle: _text(raw['eventTitle'], HandoffLimits.maxTitleLength),
      sessionDate: _date(raw['sessionDate']),
      roster: people,
    );
  }

  static HandoffResult _decodeResult(Map raw) {
    _exactKeys(
      raw,
      const {
        'app',
        'kind',
        'version',
        'eventId',
        'sessionDate',
        'helperName',
        'marks',
        'guests',
      },
      optional: const {'helperName'},
    );
    final marks = <HandoffMark>[];
    final seen = <String>{};
    for (final entry in _list(raw['marks'], HandoffLimits.maxMarks, 'marks')) {
      final map = _map(entry, const {
        'memberId',
        'name',
        'status',
        'recordedAt',
      });
      final memberId = _id(map['memberId']);
      if (!seen.add(memberId)) {
        throw const HandoffFormatException(
          'This result file marks the same person twice.',
        );
      }
      marks.add(HandoffMark(
        memberId: memberId,
        name: _text(map['name'], HandoffLimits.maxNameLength),
        status: _status(map['status']),
        recordedAt: _timestamp(map['recordedAt']),
      ));
    }
    final guests = <HandoffGuest>[];
    for (final entry
        in _list(raw['guests'], HandoffLimits.maxGuests, 'guests')) {
      final map = _map(entry, const {'name', 'recordedAt'});
      guests.add(HandoffGuest(
        name: _text(map['name'], HandoffLimits.maxNameLength),
        recordedAt: _timestamp(map['recordedAt']),
      ));
    }
    return HandoffResult(
      eventId: _id(raw['eventId']),
      sessionDate: _date(raw['sessionDate']),
      helperName: raw.containsKey('helperName')
          ? _text(raw['helperName'], HandoffLimits.maxHelperNameLength)
          : null,
      marks: marks,
      guests: guests,
    );
  }

  static const _shapeError = HandoffFormatException(
    'This handoff file is damaged or is not in the expected format.',
  );

  static void _exactKeys(
    Map raw,
    Set<String> allowed, {
    Set<String> optional = const {},
  }) {
    for (final key in raw.keys) {
      if (key is! String || !allowed.contains(key)) throw _shapeError;
    }
    for (final key in allowed) {
      if (!optional.contains(key) && !raw.containsKey(key)) throw _shapeError;
    }
  }

  static Map _map(Object? value, Set<String> keys) {
    if (value is! Map) throw _shapeError;
    _exactKeys(value, keys);
    return value;
  }

  static List _list(Object? value, int max, String what) {
    if (value is! List) throw _shapeError;
    if (value.length > max) {
      throw HandoffFormatException(
        'This file has too many entries in "$what" (the limit is $max).',
      );
    }
    return value;
  }

  static String _id(Object? value) {
    if (value is! String ||
        value.isEmpty ||
        value.length > HandoffLimits.maxIdLength ||
        !_idPattern.hasMatch(value)) {
      throw _shapeError;
    }
    return value;
  }

  static String _text(Object? value, int max) {
    if (value is! String) throw _shapeError;
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed.length > max ||
        _forbiddenText.hasMatch(trimmed)) {
      throw _shapeError;
    }
    return trimmed;
  }

  static AttendanceStatus _status(Object? value) {
    for (final status in AttendanceStatus.values) {
      if (value == status.name) return status;
    }
    throw _shapeError;
  }

  static DateTime _date(Object? value) {
    if (value is! String || !_datePattern.hasMatch(value)) throw _shapeError;
    final parsed = DateTime.tryParse(value);
    if (parsed == null || _formatDate(parsed) != value) throw _shapeError;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime _timestamp(Object? value) {
    if (value is! String || value.length > 40) throw _shapeError;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw _shapeError;
    return parsed.toUtc();
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
