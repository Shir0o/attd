import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/ai/ai_provider.dart';
import 'package:attendance_tracker/features/ai/ai_provider_factory.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/utils/name_corrections.dart';
import 'package:attendance_tracker/features/auth/domain/entities/credentials.dart';
import 'package:attendance_tracker/features/auth/domain/entities/google_account.dart';
import 'package:attendance_tracker/features/auth/domain/entities/user.dart';
import 'package:attendance_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:attendance_tracker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TrackingAttendanceRepository implements AttendanceRepository {
  _TrackingAttendanceRepository(this._families);

  List<Family> _families;
  List<Family>? lastSaved;

  @override
  Future<Family> addFamily(String displayName) async =>
      throw UnimplementedError();

  @override
  Future<Family> addMember(String familyId, Member member) async =>
      throw UnimplementedError();

  @override
  Future<List<Family>> fetchFamilies() async => _families;

  @override
  Future<void> saveFamilies(List<Family> families) async {
    lastSaved = families;
    _families = families;
  }
}

class _ImmediateSessionRepository implements SessionRepository {
  _ImmediateSessionRepository(this.sessions);

  final List<Session> sessions;

  @override
  Future<Session> createSession({
    required String title,
    required DateTime sessionDate,
    required String actor,
    required List<SessionRecord> records,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Session> duplicate(String sessionId, {required String actor}) async =>
      sessions.first;

  @override
  Future<List<SessionVersion>> history(String sessionId) async => const [];

  @override
  Future<List<Session>> loadSessions({bool includeDeleted = false}) async =>
      sessions;

  @override
  Future<Session?> revertToPrevious(String sessionId,
      {required String actor}) async =>
          sessions.first;

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async =>
      session;
}

class _ImmediateAuthRepository implements AuthRepository {
  User? _user = const User(
    id: 'user-1',
    email: 'tester@example.com',
    displayName: 'tester',
  );

  @override
  Future<User?> currentUser() async => _user;

  @override
  Future<User> login(Credentials credentials) async => _user!;

  @override
  Future<User> loginWithGoogle(GoogleAccount account) async => _user!;

  @override
  Future<void> logout() async {
    _user = null;
  }

  @override
  Future<User> signup(Credentials credentials) async => _user!;
}

class _StubAiProvider implements AiProvider {
  _StubAiProvider({required this.suggestion, required this.predictions});

  final FollowUpSuggestion suggestion;
  final List<AbsencePrediction> predictions;

  @override
  Future<FollowUpSuggestion> suggestFollowUp(
    FollowUpRequest request,
  ) async {
    return suggestion;
  }

  @override
  Future<List<AbsencePrediction>> predictAbsences(
    AbsencePredictionRequest request,
  ) async {
    return predictions;
  }
}

class _StubAiProviderFactory extends AiProviderFactory {
  const _StubAiProviderFactory(this.provider);

  final AiProvider provider;

  @override
  AiProvider create(AiProviderType type, {String? endpointOverride}) {
    return provider;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final twoDaysAgo = today.subtract(const Duration(days: 2));
  final sessions = [
    Session(
      id: 's1',
      title: 'Weekly meetup',
      sessionDate: yesterday,
      records: [
        SessionRecord(
          attendee: 'Alex',
          status: AttendanceStatus.absent,
          recordedAt: yesterday,
          recordedBy: 'coach',
        ),
        SessionRecord(
          attendee: 'Alyx',
          status: AttendanceStatus.present,
          recordedAt: yesterday,
          recordedBy: 'coach',
        ),
      ],
      createdAt: now,
      updatedAt: now,
      createdBy: 'coach',
    ),
    Session(
      id: 's2',
      title: 'Weekend check-in',
      sessionDate: twoDaysAgo,
      records: [
        SessionRecord(
          attendee: 'Alex',
          status: AttendanceStatus.absent,
          recordedAt: twoDaysAgo,
          recordedBy: 'coach',
        ),
        SessionRecord(
          attendee: 'Alyx',
          status: AttendanceStatus.present,
          recordedAt: twoDaysAgo,
          recordedBy: 'coach',
        ),
      ],
      createdAt: now,
      updatedAt: now,
      createdBy: 'coach',
    ),
  ];

  final families = [
    Family(
      id: 'fam-1',
      displayName: 'Rivera Family',
      members: const [
        Member(id: 'm1', displayName: 'Alex'),
        Member(id: 'm2', displayName: 'Alyx'),
      ],
    ),
  ];

  final suggestion = FollowUpSuggestion(
    subject: 'Alex',
    message: 'Please reach out kindly.',
    reasoning: 'Absence streak detected',
    tone: 'compassionate',
    correctedName: 'Alexander',
    duplicateCandidates: const ['Alyx'],
    duplicateClusterIds: const ['cluster-1'],
    label: 'High risk',
    labelRationale: 'Recent absences',
  );

  final predictions = [
    AbsencePrediction(
      subject: 'Alex',
      reason: 'Likely to miss again',
      probability: 0.9,
      correctedName: 'Alexander',
      duplicateCandidates: const ['Alyx'],
      duplicateClusterIds: const ['cluster-2'],
      nameSuggestion: const NameSuggestion(
        suggestedName: 'Alexander',
        confidence: 0.87,
        duplicateClusterIds: ['cluster-3'],
      ),
      label: 'High risk',
      labelRationale: 'Recent absences',
    ),
  ];

  late _TrackingAttendanceRepository repository;
  late _ImmediateSessionRepository sessionRepository;
  late _StubAiProvider provider;

  setUp(() {
    repository = _TrackingAttendanceRepository(families);
    sessionRepository = _ImmediateSessionRepository(sessions);
    provider = _StubAiProvider(
      suggestion: suggestion,
      predictions: predictions,
    );
  });

  testWidgets('shows corrected name, duplicates, and label chips', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceApp(
          repository: repository,
          sessionRepository: sessionRepository,
          aiProvider: provider,
          aiFactory: _StubAiProviderFactory(provider),
          providerType: AiProviderType.mock,
          aiEnabled: true,
          authRepository: _ImmediateAuthRepository(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Wellness watchlist'), 600);
    await tester.pumpAndSettle();

    final suggestButton = find.text('Suggest message');
    expect(suggestButton, findsWidgets);

    await tester.tap(suggestButton.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Wellness watchlist'), findsOneWidget);
    expect(find.text('Suggested name: Alexander'), findsWidgets);
    expect(find.text('Alyx'), findsWidgets);
    expect(find.text('High risk'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == 'Recent absences',
      ),
      findsWidgets,
    );
  });

  testWidgets('apply action updates saved families for duplicates', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceApp(
          repository: repository,
          sessionRepository: sessionRepository,
          aiProvider: provider,
          aiFactory: _StubAiProviderFactory(provider),
          providerType: AiProviderType.mock,
          aiEnabled: true,
          authRepository: _ImmediateAuthRepository(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Wellness watchlist'), 600);
    final suggestButton = find.text('Suggest message');
    expect(suggestButton, findsWidgets);

    await tester.tap(suggestButton.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Suggested name: Alexander'), findsWidgets);
    expect(find.text('Apply'), findsWidgets);

    final updatedFamilies = applyNameCorrection(
      families: await repository.fetchFamilies(),
      subject: 'Alex',
      correctedName: 'Alexander',
      duplicateCandidates: const ['Alyx'],
    );
    await repository.saveFamilies(updatedFamilies);

    final savedFamilies = repository.lastSaved;
    expect(savedFamilies, isNotNull);
    final members = savedFamilies!.single.members;
    expect(members.map((m) => m.displayName), everyElement('Alexander'));
  });
}
