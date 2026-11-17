import 'dart:io';

import 'package:attendance_tracker/features/handoff/data/handoff_sharer.dart';
import 'package:attendance_tracker/features/handoff/domain/handoff_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

HandoffRoster _doc() => HandoffRoster(
      eventId: 'ev-1',
      eventTitle: 'Sunday Service',
      sessionDate: DateTime(2026, 11, 15),
      roster: const [HandoffPerson(id: 'm1', name: 'Alice')],
    );

void main() {
  group('fileNameFor', () {
    test('slugs the title and adds the date and extension', () {
      expect(
        HandoffSharer.fileNameFor('Sunday Service!', DateTime(2026, 11, 5)),
        'sunday-service-2026-11-05.attdhandoff',
      );
    });

    test('a result file name carries the suffix', () {
      expect(
        HandoffSharer.fileNameFor(
          'Youth',
          DateTime(2026, 11, 15),
          suffix: 'marks',
        ),
        'youth-2026-11-15-marks.attdhandoff',
      );
    });

    test('nothing in the title can reach the path', () {
      final name = HandoffSharer.fileNameFor(
        '../../etc/passwd\u0000 \\ ..',
        DateTime(2026, 11, 15),
      );
      expect(name, matches(RegExp(r'^[a-z0-9-]+\.attdhandoff$')));
      expect(name, isNot(contains('..')));
    });

    test('blank and over-long titles stay usable', () {
      expect(
        HandoffSharer.fileNameFor('???', DateTime(2026, 11, 15)),
        startsWith('event-'),
      );
      final long = HandoffSharer.fileNameFor('a' * 200, DateTime(2026, 11, 15));
      expect(long.length, lessThan(70));
    });
  });

  group('send', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('handoff_test'));
    tearDown(() => temp.deleteSync(recursive: true));

    test('writes the file and shares it with the handoff MIME type', () async {
      List<XFile>? shared;
      String? sharedText;
      final sharer = HandoffSharer(
        directoryProvider: () async => temp,
        shareFiles: (files, {text}) async {
          shared = files;
          sharedText = text;
        },
      );

      await sharer.send(
        document: _doc(),
        fileName: '../evil/name.attdhandoff',
        text: 'Hello',
      );

      final file = shared!.single;
      expect(file.mimeType, handoffMimeType);
      expect(file.path, startsWith(temp.path));
      expect(file.path, endsWith('name.attdhandoff'));
      expect(sharedText, 'Hello');
      final back = HandoffCodec.decodeBytes(await file.readAsBytes());
      expect((back as HandoffRoster).roster.single.name, 'Alice');
    });

    test('clears files left from an earlier handoff', () async {
      final sharer = HandoffSharer(
        directoryProvider: () async => temp,
        shareFiles: (files, {text}) async {},
      );
      await sharer.send(document: _doc(), fileName: 'a.attdhandoff', text: '');
      await sharer.send(document: _doc(), fileName: 'b.attdhandoff', text: '');

      final names = Directory('${temp.path}/handoff')
          .listSync()
          .map((e) => e.uri.pathSegments.last)
          .toList();
      expect(names, ['b.attdhandoff']);
    });

    test('an invalid document is refused before anything is shared', () async {
      var shareCalled = false;
      final sharer = HandoffSharer(
        directoryProvider: () async => temp,
        shareFiles: (files, {text}) async => shareCalled = true,
      );
      final bad = HandoffRoster(
        eventId: 'bad id',
        eventTitle: 'T',
        sessionDate: DateTime(2026, 11, 15),
        roster: const [],
      );
      await expectLater(
        sharer.send(document: bad, fileName: 'a.attdhandoff', text: ''),
        throwsA(isA<HandoffFormatException>()),
      );
      expect(shareCalled, isFalse);
    });
  });
}
