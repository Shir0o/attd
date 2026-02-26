import 'dart:async';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/auth/domain/entities/credentials.dart';
import 'package:attendance_tracker/features/auth/application/google_auth_service.dart';
import 'package:attendance_tracker/features/auth/domain/entities/google_account.dart';
import 'package:attendance_tracker/features/auth/domain/entities/user.dart';
import 'package:attendance_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/hub/data/event_repository.dart';
import 'package:attendance_tracker/features/hub/domain/event.dart';
import 'package:attendance_tracker/features/settings/application/theme_controller.dart';
import 'package:attendance_tracker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuthRepository implements AuthRepository {
  _TestAuthRepository({
    this.shouldFailLogin = false,
    this.shouldFailGoogle = false,
    this.shouldFailCurrentUser = false,
  });

  bool shouldFailLogin = false;
  bool shouldFailSignup = false;
  bool shouldFailGoogle = false;
  bool shouldFailCurrentUser = false;
  User? _user;

  @override
  Future<User?> currentUser() async {
    if (shouldFailCurrentUser) {
      throw AuthException('Unable to restore session');
    }
    return _user;
  }

  @override
  Future<User> login(Credentials credentials) async {
    if (shouldFailLogin) {
      throw AuthException('Invalid email or password');
    }
    _user = User(id: 'user-${credentials.email}', email: credentials.email);
    return _user!;
  }

  @override
  Future<User> loginWithGoogle(GoogleAccount account) async {
    if (shouldFailGoogle) {
      throw AuthException('Google sign-in failed');
    }
    _user = User(
      id: 'google-${account.id}',
      email: account.email,
      displayName: account.displayName ?? account.email,
    );
    return _user!;
  }

  @override
  Future<void> logout() async {
    _user = null;
  }

  @override
  Future<User> signup(Credentials credentials) async {
    if (shouldFailSignup) {
      throw AuthException('An account with that email already exists');
    }
    _user = User(id: 'user-${credentials.email}', email: credentials.email);
    return _user!;
  }
}

class _TestGoogleAuthService implements GoogleAuthService {
  _TestGoogleAuthService({this.account});

  GoogleAccount? account;
  bool shouldThrow = false;
  bool signOutCalled = false;

  @override
  Future<GoogleAccount?> signIn() async {
    if (shouldThrow) {
      throw Exception('Google sign in failed');
    }
    return account;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

class _StubAttendanceRepository implements AttendanceRepository {
  @override
  Future<Family> addMember(String familyId, Member member) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Family>> fetchFamilies() async {
    return const [];
  }

  @override
  Future<void> saveFamilies(List<Family> families) async {}

  @override
  Future<Family> addFamily(String displayName) async {
    throw UnimplementedError();
  }

  @override
  Future<void> refresh() async {}
}

class _StubSessionRepository implements SessionRepository {
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
  Future<Session> duplicate(String sessionId, {required String actor}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<SessionVersion>> history(String sessionId) async {
    return const [];
  }

  @override
  Future<List<Session>> loadSessions({bool includeDeleted = false}) async {
    return const [];
  }

  @override
  Future<Session?> revertToPrevious(
    String sessionId, {
    required String actor,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    return session;
  }

  @override
  Future<void> refresh() async {}
}

class MockEventRepository implements EventRepository {
  final _controller = StreamController<List<Event>>();

  void emit(List<Event> events) {
    _controller.add(events);
  }

  @override
  Future<void> createEvent(Event event) async {}

  @override
  Future<void> updateEvent(Event event) async {}

  @override
  Future<void> deleteEvent(String eventId) async {}

  @override
  Stream<List<Event>> streamEvents() {
    return _controller.stream;
  }

  @override
  Future<void> refresh() async {}
}

void main() {
  late ThemeController themeController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    themeController = ThemeController(prefs);
  });

  testWidgets('requires email and password before submission', (tester) async {
    final authRepository = _TestAuthRepository();
    final mockEventRepo = MockEventRepository();
    mockEventRepo.emit([]);

    await tester.pumpWidget(
      AttendanceApp(
        themeController: themeController,
        repository: _StubAttendanceRepository(),
        sessionRepository: _StubSessionRepository(),
        eventRepository: mockEventRepo,
        authRepository: authRepository,
        googleAuthService: _TestGoogleAuthService(account: null),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('signs up a new user and loads the home page', (tester) async {
    final authRepository = _TestAuthRepository();
    final mockEventRepo = MockEventRepository();
    mockEventRepo.emit([]);

    await tester.pumpWidget(
      AttendanceApp(
        themeController: themeController,
        repository: _StubAttendanceRepository(),
        sessionRepository: _StubSessionRepository(),
        eventRepository: mockEventRepo,
        authRepository: authRepository,
        googleAuthService: _TestGoogleAuthService(account: null),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switchAuthModeButton')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('authEmailField')),
      'newuser@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('authPasswordField')),
      'password',
    );
    await tester.tap(find.byKey(const Key('authSubmitButton')));

    await tester.pumpAndSettle();
    // Expect HubPage elements
    expect(find.text('TODAY'), findsOneWidget);
  });

  testWidgets('shows auth form if restoring the session fails', (tester) async {
    final authRepository = _TestAuthRepository(shouldFailCurrentUser: true);
    final mockEventRepo = MockEventRepository();
    mockEventRepo.emit([]);

    await tester.pumpWidget(
      AttendanceApp(
        themeController: themeController,
        repository: _StubAttendanceRepository(),
        sessionRepository: _StubSessionRepository(),
        eventRepository: mockEventRepo,
        authRepository: authRepository,
        googleAuthService: _TestGoogleAuthService(account: null),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('authEmailField')), findsOneWidget);
    expect(find.text('Unable to restore session'), findsOneWidget);
  });

  testWidgets('shows an error message when login fails', (tester) async {
    final authRepository = _TestAuthRepository(shouldFailLogin: true);
    final mockEventRepo = MockEventRepository();
    mockEventRepo.emit([]);

    await tester.pumpWidget(
      AttendanceApp(
        themeController: themeController,
        repository: _StubAttendanceRepository(),
        sessionRepository: _StubSessionRepository(),
        eventRepository: mockEventRepo,
        authRepository: authRepository,
        googleAuthService: _TestGoogleAuthService(account: null),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('authEmailField')),
      'demo@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('authPasswordField')),
      'password',
    );
    await tester.tap(find.byKey(const Key('authSubmitButton')));

    await tester.pumpAndSettle();
    expect(find.text('Invalid email or password'), findsOneWidget);
  });

  testWidgets('signs out and returns to auth screen', (tester) async {
    final authRepository = _TestAuthRepository();
    final mockEventRepo = MockEventRepository();
    mockEventRepo.emit([]);

    await tester.pumpWidget(
      AttendanceApp(
        themeController: themeController,
        repository: _StubAttendanceRepository(),
        sessionRepository: _StubSessionRepository(),
        eventRepository: mockEventRepo,
        authRepository: authRepository,
        googleAuthService: _TestGoogleAuthService(account: null),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('authEmailField')),
      'demo@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('authPasswordField')),
      'password',
    );
    await tester.tap(find.byKey(const Key('authSubmitButton')));

    await tester.pumpAndSettle();

    // Find logout icon
    expect(find.byIcon(Icons.logout), findsOneWidget);

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('authEmailField')), findsOneWidget);
    expect(find.byKey(const Key('authSubmitButton')), findsOneWidget);
  });

  testWidgets('continues with Google and loads the home page', (tester) async {
    final authRepository = _TestAuthRepository();
    final mockEventRepo = MockEventRepository();
    mockEventRepo.emit([]);

    final googleService = _TestGoogleAuthService(
      account: const GoogleAccount(
        id: 'google-1',
        email: 'demo@example.com',
        displayName: 'Demo User',
      ),
    );

    await tester.pumpWidget(
      AttendanceApp(
        themeController: themeController,
        repository: _StubAttendanceRepository(),
        sessionRepository: _StubSessionRepository(),
        eventRepository: mockEventRepo,
        authRepository: authRepository,
        googleAuthService: googleService,
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pumpAndSettle();

    expect(find.text('TODAY'), findsOneWidget);
  });

  testWidgets('returns to auth screen when Google sign-in is cancelled', (
    tester,
  ) async {
    final authRepository = _TestAuthRepository();
    final mockEventRepo = MockEventRepository();
    mockEventRepo.emit([]);

    final googleService = _TestGoogleAuthService(account: null);

    await tester.pumpWidget(
      AttendanceApp(
        themeController: themeController,
        repository: _StubAttendanceRepository(),
        sessionRepository: _StubSessionRepository(),
        eventRepository: mockEventRepo,
        authRepository: authRepository,
        googleAuthService: googleService,
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pumpAndSettle();

    expect(find.text('TODAY'), findsNothing);
    expect(find.text('Login'), findsWidgets);
  });

  testWidgets('shows an error message when Google sign-in fails', (
    tester,
  ) async {
    final authRepository = _TestAuthRepository(shouldFailGoogle: true);
    final mockEventRepo = MockEventRepository();
    mockEventRepo.emit([]);

    final googleService = _TestGoogleAuthService(
      account: const GoogleAccount(id: 'google-1', email: 'demo@example.com'),
    );

    await tester.pumpWidget(
      AttendanceApp(
        themeController: themeController,
        repository: _StubAttendanceRepository(),
        sessionRepository: _StubSessionRepository(),
        eventRepository: mockEventRepo,
        authRepository: authRepository,
        googleAuthService: googleService,
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pumpAndSettle();

    expect(find.text('Google sign-in failed'), findsOneWidget);
  });
}
