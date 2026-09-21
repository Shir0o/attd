import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/presentation/session_summary_page.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/settings/data/cisa_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSessionRepository implements SessionRepository {
  @override
  Future<Session> createSession({
    required String title,
    String? eventId,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async => throw UnimplementedError();
  @override
  Future<void> deleteSession(String sessionId, {required String actor}) async {}
  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async => throw UnimplementedError();
  @override
  Future<Session?> findSessionById(String id) async => null;
  @override
  Future<List<SessionVersion>> history(String sessionId) async => [];
  @override
  Future<List<Session>> loadSessions() async => [];
  @override
  Future<void> migrateRecords(Map<String, String> nameToIdMap) async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async => session;
  @override
  Stream<List<Session>> streamSessions() => Stream.value([]);
}

class _MockAttendanceRepository extends AttendanceRepository {
  @override
  Future<Family> addFamily(String displayName, {bool isAutoSingleton = false}) async =>
      throw UnimplementedError();
  @override
  Future<Family> addMember(String familyId, Member member) async =>
      throw UnimplementedError();
  @override
  Future<List<Family>> fetchFamilies() async => [];
  @override
  Future<void> saveFamilies(List<Family> families) async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
  @override
  Stream<List<Family>> streamFamilies() => Stream.value([]);
}

class _MockEventRepository implements EventRepository {
  @override
  Future<void> createEvent(Event event) async {}
  @override
  Future<void> updateEvent(Event event) async {}
  @override
  Future<void> deleteEvent(String eventId) async {}
  @override
  Future<Event?> findEventById(String eventId) async => null;
  @override
  Stream<List<Event>> streamEvents() => Stream.value([]);
  @override
  Future<void> refresh() async {}
  @override
  Future<void> pruneSoftDeleted(DateTime threshold) async {}
}

class _MockCisaSyncService extends Mock implements CisaSyncService {}
class _FakeSession extends Fake implements Session {}
class _FakeEvent extends Fake implements Event {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_FakeSession());
    registerFallbackValue(_FakeEvent());
  });

  late Session testSession;
  late List<Member> testMembers;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    testSession = Session(
      id: 's-101',
      title: 'Youth Fellowship',
      sessionDate: DateTime(2026, 9, 21, 19, 0),
      createdAt: DateTime(2026, 9, 21, 19, 0),
      updatedAt: DateTime(2026, 9, 21, 20, 0),
      createdBy: 'Leader',
      records: [
        SessionRecord(
          memberId: 'm-1',
          attendee: 'Alex',
          status: AttendanceStatus.present,
          recordedAt: DateTime(2026, 9, 21, 19, 5),
          recordedBy: 'Leader',
        ),
      ],
    );
    testMembers = [Member(id: 'm-1', displayName: 'Alex')];
  });

  testWidgets('renders Sync to CISA button on SessionSummaryPage', (tester) async {
    final mockCisaService = _MockCisaSyncService();
    when(() => mockCisaService.close()).thenReturn(null);

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: testSession,
          members: testMembers,
          sessionRepository: _MockSessionRepository(),
          attendanceRepository: _MockAttendanceRepository(),
          eventRepository: _MockEventRepository(),
          cisaSyncService: mockCisaService,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sync_cisa_button')), findsOneWidget);
    expect(find.byTooltip('Sync to CISA Gathering'), findsOneWidget);
  });

  testWidgets('shows warning snackbar when CISA sync is not configured', (tester) async {
    final mockCisaService = _MockCisaSyncService();
    when(() => mockCisaService.close()).thenReturn(null);
    when(() => mockCisaService.syncSession(
      session: any(named: 'session'),
      event: any(named: 'event'),
    )).thenAnswer((_) async => const CisaSyncResult(
      success: false,
      isConfigured: false,
      errorMessage: 'CISA Sync URL and Token must be configured in Settings.',
    ));

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: testSession,
          members: testMembers,
          sessionRepository: _MockSessionRepository(),
          attendanceRepository: _MockAttendanceRepository(),
          eventRepository: _MockEventRepository(),
          cisaSyncService: mockCisaService,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sync_cisa_button')));
    await tester.pumpAndSettle();

    expect(find.text('CISA Sync URL and Token must be configured in Settings.'), findsOneWidget);
  });

  testWidgets('shows success snackbar when CISA sync completes successfully', (tester) async {
    final mockCisaService = _MockCisaSyncService();
    when(() => mockCisaService.close()).thenReturn(null);
    when(() => mockCisaService.syncSession(
      session: any(named: 'session'),
      event: any(named: 'event'),
    )).thenAnswer((_) async => const CisaSyncResult(
      success: true,
      isConfigured: true,
      statusCode: 200,
    ));

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: testSession,
          members: testMembers,
          sessionRepository: _MockSessionRepository(),
          attendanceRepository: _MockAttendanceRepository(),
          eventRepository: _MockEventRepository(),
          cisaSyncService: mockCisaService,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sync_cisa_button')));
    await tester.pumpAndSettle();

    expect(find.text('Synced to CISA Gathering successfully!'), findsOneWidget);
  });

  testWidgets('shows error snackbar when CISA sync encounters error without breaking session', (tester) async {
    final mockCisaService = _MockCisaSyncService();
    when(() => mockCisaService.close()).thenReturn(null);
    when(() => mockCisaService.syncSession(
      session: any(named: 'session'),
      event: any(named: 'event'),
    )).thenAnswer((_) async => const CisaSyncResult(
      success: false,
      isConfigured: true,
      statusCode: 500,
      errorMessage: 'Server error (500): Internal error.',
    ));

    await tester.pumpWidget(
      MaterialApp(
        home: SessionSummaryPage(
          session: testSession,
          members: testMembers,
          sessionRepository: _MockSessionRepository(),
          attendanceRepository: _MockAttendanceRepository(),
          eventRepository: _MockEventRepository(),
          cisaSyncService: mockCisaService,
          disableAnimations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sync_cisa_button')));
    await tester.pumpAndSettle();

    expect(find.text('Server error (500): Internal error.'), findsOneWidget);
  });
}
