import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/settings/presentation/manage_backup_data_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _AttendanceRepository implements AttendanceRepository {
  List<Family> families;
  int saveCount = 0;
  Object? fetchError;
  Object? saveError;

  _AttendanceRepository(this.families);

  @override
  Future<Family> addFamily(String displayName) async {
    throw UnimplementedError();
  }

  @override
  Future<Family> addMember(String familyId, Member member) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Family>> fetchFamilies() async {
    if (fetchError != null) throw fetchError!;
    return families;
  }

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> saveFamilies(List<Family> families) async {
    saveCount++;
    if (saveError != null) throw saveError!;
    this.families = families;
  }

  @override
  Stream<List<Family>> streamFamilies() => Stream.value(families);
}

class _EventRepository implements EventRepository {
  List<Event> events;
  int deleteCount = 0;

  _EventRepository(this.events);

  @override
  Future<void> createEvent(Event event) async {}

  @override
  Future<void> deleteEvent(String eventId) async {
    deleteCount++;
    events = events.where((event) => event.id != eventId).toList();
  }

  @override
  Future<Event?> findEventById(String eventId) async => null;

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<void> refresh() async {}

  @override
  Stream<List<Event>> streamEvents() => Stream.value(events);

  @override
  Future<void> updateEvent(Event event) async {}
}

class _SessionRepository implements SessionRepository {
  List<Session> sessions;
  int deleteCount = 0;

  _SessionRepository(this.sessions);

  @override
  Future<Session> createSession({
    required String title,
    String? eventId,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {
    deleteCount++;
    sessions = sessions.where((session) => session.id != sessionId).toList();
  }

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async {
    throw UnimplementedError();
  }

  @override
  Future<Session?> findSessionById(String id) async => null;

  @override
  Future<List<SessionVersion>> history(String sessionId) async => [];

  @override
  Future<List<Session>> loadSessions() async => sessions;

  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}

  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async =>
      session;

  @override
  Stream<List<Session>> streamSessions() => Stream.value(sessions);
}

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('renders backup data, filters search, and saves deletions', (
    tester,
  ) async {
    final now = DateTime(2025, 4, 5, 10);
    final member = Member(
      id: 'member-1234',
      displayName: 'Alice Member',
      updatedAt: now,
    );
    final attendance = _AttendanceRepository([
      Family(
        id: 'family-1',
        displayName: 'Alpha Family',
        members: [member],
        updatedAt: now,
      ),
    ]);
    final events = _EventRepository([
      Event(
        id: 'event-1',
        title: 'Choir Event',
        time: const TimeOfDay(hour: 9, minute: 0),
        frequency: 'Weekly',
        createdAt: now,
      ),
    ]);
    final sessions = _SessionRepository([
      Session(
        id: 'session-1',
        title: 'Sunday Session',
        sessionDate: now,
        records: [
          SessionRecord(
            memberId: member.id,
            attendee: member.displayName,
            status: AttendanceStatus.present,
            recordedAt: now,
            recordedBy: 'tester',
          ),
        ],
        createdAt: now,
        updatedAt: now,
        createdBy: 'tester',
      ),
    ]);

    await tester.pumpWidget(
      _wrap(
        ManageBackupDataPage(
          attendanceRepository: attendance,
          eventRepository: events,
          sessionRepository: sessions,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manage Backup Data'), findsOneWidget);
    expect(find.text('Choir Event'), findsOneWidget);
    expect(find.text('Alice Member'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'choir');
    await tester.pump();
    expect(find.text('Choir Event'), findsOneWidget);
    expect(find.text('Alice Member'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.delete).at(0));
    await tester.pump();
    final memberDelete = find.byKey(
      const ValueKey('delete_Alice Member_ID: #memb'),
    );
    await tester.tap(memberDelete);
    await tester.pumpAndSettle();

    expect(find.text('Historical Data Alert'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final sessionDelete = find.byKey(
      const ValueKey('delete_Sunday Session_Apr 05, 2025 10:00 AM'),
    ).last;
    await tester.scrollUntilVisible(
      sessionDelete,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(sessionDelete);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('save_cleaned_backup_button')));
    await tester.pumpAndSettle();

    expect(events.deleteCount, 1);
    expect(sessions.deleteCount, 1);
    expect(attendance.saveCount, 1);
    expect(attendance.families.single.members, isEmpty);
  });

  testWidgets('logs and recovers when fetchFamilies throws on load',
      (tester) async {
    final attendance = _AttendanceRepository([])..fetchError = Exception('io');
    final events = _EventRepository([]);
    final sessions = _SessionRepository([]);

    await tester.pumpWidget(
      _wrap(
        ManageBackupDataPage(
          attendanceRepository: attendance,
          eventRepository: events,
          sessionRepository: sessions,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The page must render its scaffold rather than crash.
    expect(find.text('Local Records Snapshot'), findsOneWidget);
  });

  testWidgets('handles empty and failed backup loads', (tester) async {
    final attendance = _AttendanceRepository([]);
    final events = _EventRepository([]);
    final sessions = _SessionRepository([]);

    await tester.pumpWidget(
      _wrap(
        ManageBackupDataPage(
          attendanceRepository: attendance,
          eventRepository: events,
          sessionRepository: sessions,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local Records Snapshot'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });
}
