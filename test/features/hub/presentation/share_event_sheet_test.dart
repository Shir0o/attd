import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/data/event_sharing_service.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/hub/presentation/share_event_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:mocktail/mocktail.dart';

class MockEventSharingService extends Mock implements EventSharingService {}
class MockEventRepository extends Mock implements EventRepository {}
class MockAttendanceRepository extends Mock implements AttendanceRepository {}
class MockSessionRepository extends Mock implements SessionRepository {}

class FakeEvent extends Fake implements Event {}
class FakeSharedSlice extends Fake implements SharedSlice {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeEvent());
    registerFallbackValue(FakeSharedSlice());
  });

  group('ShareEventSheet Widget Tests', () {
    late MockEventSharingService mockSharingService;
    late MockEventRepository mockEventRepo;
    late MockAttendanceRepository mockAttendanceRepo;
    late MockSessionRepository mockSessionRepo;
    late Event testEvent;

    setUp(() {
      mockSharingService = MockEventSharingService();
      mockEventRepo = MockEventRepository();
      mockAttendanceRepo = MockAttendanceRepository();
      mockSessionRepo = MockSessionRepository();

      testEvent = Event(
        id: 'ev-1',
        title: 'Weekly Meetup',
        time: const TimeOfDay(hour: 10, minute: 0),
        frequency: 'Weekly',
        createdAt: DateTime.utc(2026, 9, 21),
      );

      when(() => mockSharingService.listCollaborators(any()))
          .thenAnswer((_) async => []);
      when(() => mockAttendanceRepo.fetchFamilies())
          .thenAnswer((_) async => []);
      when(() => mockSessionRepo.loadSessions())
          .thenAnswer((_) async => []);
      when(() => mockEventRepo.updateEvent(any()))
          .thenAnswer((_) async {});
    });

    Widget createWidget({Event? event}) {
      return MaterialApp(
        home: Scaffold(
          body: ShareEventSheet(
            event: event ?? testEvent,
            eventSharingService: mockSharingService,
            eventRepository: mockEventRepo,
            attendanceRepository: mockAttendanceRepo,
            sessionRepository: mockSessionRepo,
          ),
        ),
      );
    }

    testWidgets('renders share event toggle and title', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Share Event'), findsOneWidget);
      expect(find.text('Share this event'), findsOneWidget);
      expect(find.byKey(const Key('shareEventSwitch')), findsOneWidget);
    });

    testWidgets('toggling share switch creates folder and uploads slice', (tester) async {
      when(() => mockSharingService.createSharedEventFolder(any()))
          .thenAnswer((_) async => 'folder-123');
      when(() => mockSharingService.uploadSharedSlice(any(), any()))
          .thenAnswer((_) async {});

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Tap switch to enable
      await tester.tap(find.byKey(const Key('shareEventSwitch')));
      await tester.pumpAndSettle();

      verify(() => mockSharingService.createSharedEventFolder(any())).called(1);
      verify(() => mockSharingService.uploadSharedSlice('folder-123', any())).called(1);
      verify(() => mockEventRepo.updateEvent(any(that: predicate<Event>((e) => e.isShared && e.sharedFolderId == 'folder-123')))).called(1);
    });

    testWidgets('renders collaborators list and handles invite', (tester) async {
      final sharedEvent = testEvent.copyWith(
        isShared: true,
        sharedFolderId: 'folder-123',
        collaborators: ['collab@gmail.com'],
      );

      when(() => mockSharingService.listCollaborators('folder-123')).thenAnswer(
        (_) async => [
          drive.Permission(id: 'p1', role: 'writer', type: 'user', emailAddress: 'collab@gmail.com', displayName: 'Collab User')
        ],
      );
      when(() => mockSharingService.inviteCollaborator('folder-123', 'new@gmail.com')).thenAnswer(
        (_) async => drive.Permission(id: 'p2', role: 'writer', type: 'user', emailAddress: 'new@gmail.com'),
      );

      await tester.pumpWidget(createWidget(event: sharedEvent));
      await tester.pumpAndSettle();

      expect(find.text('Collab User'), findsOneWidget);
      expect(find.text('collab@gmail.com'), findsOneWidget);

      // Enter new email and invite
      await tester.enterText(find.byKey(const Key('addCollaboratorEmailInput')), 'new@gmail.com');
      await tester.tap(find.byKey(const Key('inviteCollaboratorBtn')));
      await tester.pumpAndSettle();

      verify(() => mockSharingService.inviteCollaborator('folder-123', 'new@gmail.com')).called(1);
    });
  });
}
