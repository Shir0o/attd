import 'dart:io';

import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/data/session_version.dart';
import 'package:attendance_tracker/features/auth/domain/entities/credentials.dart';
import 'package:attendance_tracker/features/auth/domain/entities/user.dart';
import 'package:attendance_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _InMemoryAttendanceRepository implements AttendanceRepository {
  _InMemoryAttendanceRepository({List<Family>? families})
    : _families = List<Family>.from(families ?? _defaultFamilies);

  List<Family> _families;

  @override
  AttendanceStore get store => AttendanceStore.localJson;

  @override
  Future<Family> addVisitor(String familyId, Member visitor) async {
    final updated = _families.map((family) {
      if (family.id != familyId) return family;
      return family.copyWith(members: [...family.members, visitor]);
    }).toList();
    _families = updated;
    return updated.firstWhere((family) => family.id == familyId);
  }

  @override
  Future<List<Family>> fetchFamilies() async {
    return _families;
  }

  @override
  Future<void> saveFamilies(List<Family> families) async {
    _families = List<Family>.from(families);
  }
}

const _defaultFamilies = [
  Family(
    id: 'family-1',
    displayName: 'Rivera Family',
    members: [
      Member(id: 'member-1', displayName: 'Alana Rivera'),
      Member(id: 'member-2', displayName: 'Mateo Rivera'),
      Member(id: 'member-3', displayName: 'Sofia Rivera'),
    ],
  ),
  Family(
    id: 'family-2',
    displayName: 'Nguyen Family',
    members: [
      Member(id: 'member-4', displayName: 'Minh Nguyen'),
      Member(id: 'member-5', displayName: 'Linh Nguyen'),
    ],
  ),
  Family(
    id: 'family-3',
    displayName: 'Patel Family',
    members: [
      Member(id: 'member-6', displayName: 'Aarav Patel'),
      Member(id: 'member-7', displayName: 'Anaya Patel'),
      Member(id: 'member-8', displayName: 'Rishi Patel'),
      Member(id: 'member-9', displayName: 'Priya Patel'),
    ],
  ),
];

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
  Future<Session> duplicate(String sessionId, {required String actor}) async {
    return sessions.first;
  }

  @override
  Future<List<SessionVersion>> history(String sessionId) async {
    return const [];
  }

  @override
  Future<List<Session>> loadSessions({bool includeDeleted = false}) async {
    return sessions;
  }

  @override
  Future<Session?> revertToPrevious(
    String sessionId, {
    required String actor,
  }) async {
    return sessions.first;
  }

  @override
  Future<Session> saveSnapshot(Session session, {required String actor}) async {
    return session;
  }
}

class _ImmediateAuthRepository implements AuthRepository {
  User? _user = const User(id: 'user-1', username: 'tester');

  @override
  Future<User?> currentUser() async => _user;

  @override
  Future<User> login(Credentials credentials) async => _user!;

  @override
  Future<void> logout() async {
    _user = null;
  }

  @override
  Future<User> signup(Credentials credentials) async => _user!;
}

void main() {
  testWidgets('Shows analytics overview and actions', (tester) async {
    sqfliteFfiInit();

    final repository = _InMemoryAttendanceRepository();
    final sessionRepository = _ImmediateSessionRepository(buildSeedSessions());

    await tester.pumpWidget(
      AttendanceApp(
        repository: repository,
        sessionRepository: sessionRepository,
        authRepository: _ImmediateAuthRepository(),
        authDirectoryProvider: () async => Directory.systemTemp,
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Engagement overview'), findsOneWidget);
    expect(find.text('Attendance rate'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Wellness watchlist'), 400);
    expect(find.text('Wellness watchlist'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Recent sessions'), 800);

    expect(find.text('Export report'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Take attendance'), findsOneWidget);
    expect(find.text('Recent sessions'), findsOneWidget);
  });
}
