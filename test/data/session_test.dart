import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Session', () {
    final now = DateTime.now();
    final record = SessionRecord(
      attendee: 'John Doe',
      status: AttendanceStatus.present,
      recordedAt: now,
      recordedBy: 'Admin',
    );
    final session = Session(
      id: 'session-1',
      title: 'Weekly Meetup',
      sessionDate: now,
      records: [record],
      createdAt: now,
      updatedAt: now,
      createdBy: 'Admin',
      currentVersion: 1,
    );

    test('copyWith creates a new instance with updated values', () {
      final updated = session.copyWith(
        title: 'Monthly Meetup',
        currentVersion: 2,
      );
      expect(updated.title, 'Monthly Meetup');
      expect(updated.currentVersion, 2);
      expect(updated.id, session.id);
      expect(updated.records.length, 1);
    });

    test('toJson and fromJson work correctly', () {
      final json = session.toJson();
      expect(json['id'], 'session-1');
      expect(json['title'], 'Weekly Meetup');
      expect(json['records'], isA<List>());
      expect((json['records'] as List).length, 1);

      final fromJson = Session.fromJson(json);
      expect(fromJson.id, session.id);
      expect(fromJson.title, session.title);
      expect(fromJson.records.length, 1);
      expect(fromJson.records.first.attendee, record.attendee);
      expect(fromJson.currentVersion, 1);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'session-2',
        'title': 'Empty Session',
        'sessionDate': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'createdBy': 'Admin',
        // 'records' is missing, should default to empty
        // 'currentVersion' is missing, should default to 1
      };
      final fromJson = Session.fromJson(json);
      expect(fromJson.records, isEmpty);
      expect(fromJson.currentVersion, 1);
    });

    test('title should be trimmed', () {
      final untrimmed = Session(
        id: 'session-3',
        title: '  Trim Me  ',
        sessionDate: now,
        records: [],
        createdAt: now,
        updatedAt: now,
        createdBy: 'Admin',
      );
      expect(untrimmed.title, 'Trim Me');

      final fromJson = Session.fromJson({
        'id': 'session-4',
        'title': '  Json Trim  ',
        'sessionDate': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'createdBy': 'Admin',
      });
      expect(fromJson.title, 'Json Trim');
    });
  });
}
