import 'dart:io';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/auth/domain/entities/credentials.dart';
import 'package:attendance_tracker/features/auth/domain/entities/user.dart';
import 'package:attendance_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestAuthRepository implements AuthRepository {
  _TestAuthRepository({
    this.shouldFailLogin = false,
    this.shouldFailSignup = false,
  });

  bool shouldFailLogin;
  bool shouldFailSignup;
  User? _user;

  @override
  Future<User?> currentUser() async => _user;

  @override
  Future<User> login(Credentials credentials) async {
    if (shouldFailLogin) {
      throw AuthException('Invalid username or password');
    }
    _user = User(
      id: 'user-${credentials.username}',
      username: credentials.username,
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
      throw AuthException('User already exists');
    }
    _user = User(
      id: 'user-${credentials.username}',
      username: credentials.username,
    );
    return _user!;
  }
}

class _StubAttendanceRepository implements AttendanceRepository {
  @override
  AttendanceStore get store => AttendanceStore.localJson;

  @override
  Future<Family> addVisitor(String familyId, Member visitor) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Family>> fetchFamilies() async {
    return const [];
  }

  @override
  Future<void> saveFamilies(List<Family> families) async {}
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
}

void main() {
  testWidgets('requires username and password before submission', (
    tester,
  ) async {
    final authRepository = _TestAuthRepository();

    await tester.pumpWidget(
      AttendanceApp(
        repository: _StubAttendanceRepository(),
        sessionRepository: _StubSessionRepository(),
        authRepository: authRepository,
        authDirectoryProvider: () async => Directory.systemTemp,
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();

    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('signs up a new user and loads the home page', (tester) async {
    final authRepository = _TestAuthRepository();

    await tester.pumpWidget(
      AttendanceApp(
        repository: _StubAttendanceRepository(),
        sessionRepository: _StubSessionRepository(),
        authRepository: authRepository,
        authDirectoryProvider: () async => Directory.systemTemp,
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switchAuthModeButton')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('authUsernameField')),
      'newuser',
    );
    await tester.enterText(
      find.byKey(const Key('authPasswordField')),
      'password',
    );
    await tester.tap(find.byKey(const Key('authSubmitButton')));

    await tester.pumpAndSettle();
    expect(find.text('Engagement overview'), findsOneWidget);
  });

  testWidgets('shows an error message when login fails', (tester) async {
    final authRepository = _TestAuthRepository(shouldFailLogin: true);

    await tester.pumpWidget(
      AttendanceApp(
        repository: _StubAttendanceRepository(),
        sessionRepository: _StubSessionRepository(),
        authRepository: authRepository,
        authDirectoryProvider: () async => Directory.systemTemp,
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('authUsernameField')), 'demo');
    await tester.enterText(
      find.byKey(const Key('authPasswordField')),
      'password',
    );
    await tester.tap(find.byKey(const Key('authSubmitButton')));

    await tester.pumpAndSettle();
    expect(find.text('Invalid username or password'), findsOneWidget);
  });

  testWidgets('signs out and returns to auth screen', (tester) async {
    final authRepository = _TestAuthRepository();

    await tester.pumpWidget(
      AttendanceApp(
        repository: _StubAttendanceRepository(),
        sessionRepository: _StubSessionRepository(),
        authRepository: authRepository,
        authDirectoryProvider: () async => Directory.systemTemp,
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('authUsernameField')), 'demo');
    await tester.enterText(
      find.byKey(const Key('authPasswordField')),
      'password',
    );
    await tester.tap(find.byKey(const Key('authSubmitButton')));

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('signOutButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('signOutButton')));
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
  });
}
