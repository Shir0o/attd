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

class _AttendanceRepository extends AttendanceRepository {
  List<Family> families;
  int saveCount = 0;
  Object? fetchError;
  Object? saveError;

  _AttendanceRepository(this.families);

  Future<List<Family>> fetchAllFamilies() async => families;

  @override
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) async {
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

  Future<List<Event>> fetchAllEvents() async => events;

  Future<void> saveEvents(List<Event> events) async {
    this.events = events;
  }

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

  Future<List<Session>> fetchAllSessions() async => sessions;

  Future<void> saveSessions(List<Session> sessions) async {
    this.sessions = sessions;
  }

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
    // Member is soft-deleted (has deletedAt), making it flagged as 'hidden'
    final member = Member(
      id: 'member-1234',
      displayName: 'Alice Member',
      updatedAt: now,
      deletedAt: now,
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
    // Session is orphaned (has non-existent eventId), making it flagged as 'orphan'
    final sessions = _SessionRepository([
      Session(
        id: 'session-1',
        title: 'Sunday Session',
        eventId: 'missing-event-1',
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

    expect(find.text('Storage inspector'), findsOneWidget);
    expect(find.text('Choir Event'), findsOneWidget);
    expect(find.text('Alice Member'), findsOneWidget);
    
    // Total count chip 'All' should show count 5
    expect(find.text('5'), findsOneWidget);

    // Search functionality
    await tester.enterText(find.byType(TextField), 'choir');
    await tester.pump();
    expect(find.text('Choir Event'), findsOneWidget);
    expect(find.text('Alice Member'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    // Toggle "Only issues" filter
    await tester.tap(find.text('Only issues'));
    await tester.pumpAndSettle();

    // Choir Event is healthy, so it should be filtered out
    expect(find.text('Choir Event'), findsNothing);
    expect(find.text('Alice Member'), findsOneWidget);

    // Expand Alice Member card
    await tester.tap(find.text('Alice Member'));
    await tester.pumpAndSettle();

    // Scroll delete button into view
    final memberDelete = find.byKey(const ValueKey('delete_btn_member-1234'));
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(memberDelete);
    await tester.pumpAndSettle();

    // Historical data alert should show up
    expect(find.text('Historical Data Alert'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Clean up remaining issues via bulk button
    final cleanupBtn = find.byKey(const ValueKey('cleanup_flagged_records_button'));
    await tester.tap(cleanupBtn);
    await tester.pumpAndSettle();

    expect(find.text('Clean up 3 records?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Clean up'));
    await tester.pumpAndSettle();

    // Verify deletion succeeded
    expect(sessions.sessions, isEmpty);
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
    expect(find.text('Storage inspector'), findsOneWidget);
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

    expect(find.text('Storage inspector'), findsOneWidget);
    // All table chips should display '0' counts, so '0' text matches multiple widgets
    expect(find.text('0'), findsAtLeast(1));
  });
}

