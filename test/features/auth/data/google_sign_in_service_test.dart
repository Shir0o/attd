import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attendance_tracker/features/auth/data/google_sign_in_service.dart';

class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}
class MockGoogleSignInAuthentication extends Mock implements GoogleSignInAuthentication {}
class MockGoogleSignInAuthorizationClient extends Mock implements GoogleSignInAuthorizationClient {}
class MockGoogleSignInClientAuthorization extends Mock implements GoogleSignInClientAuthorization {}

void main() {
  group('GoogleSignInAuthService', () {
    late MockGoogleSignIn mockGoogleSignIn;
    late MockGoogleSignInAccount mockAccount;
    late MockGoogleSignInAuthentication mockAuth;
    late MockGoogleSignInAuthorizationClient mockAuthzClient;
    late MockGoogleSignInClientAuthorization mockAuthz;
    late GoogleSignInAuthService authService;

    setUp(() {
      mockGoogleSignIn = MockGoogleSignIn();
      mockAccount = MockGoogleSignInAccount();
      mockAuth = MockGoogleSignInAuthentication();
      mockAuthzClient = MockGoogleSignInAuthorizationClient();
      mockAuthz = MockGoogleSignInClientAuthorization();
      authService = GoogleSignInAuthService(googleSignIn: mockGoogleSignIn);
    });

    test('currentUser is initially null', () {
      expect(authService.currentUser, isNull);
    });

    test('signIn returns null if supportsAuthenticate is false', () async {
      when(() => mockGoogleSignIn.supportsAuthenticate()).thenReturn(false);

      final result = await authService.signIn();

      expect(result, isNull);
      expect(authService.currentUser, isNull);
      verify(() => mockGoogleSignIn.supportsAuthenticate()).called(1);
      verifyNever(() => mockGoogleSignIn.authenticate());
    });

    test('signIn returns GoogleAccount when auth and authorization succeed (cached authz)', () async {
      when(() => mockGoogleSignIn.supportsAuthenticate()).thenReturn(true);
      when(() => mockGoogleSignIn.authenticate()).thenAnswer((_) async => mockAccount);
      when(() => mockAccount.id).thenReturn('user_123');
      when(() => mockAccount.email).thenReturn('user@example.com');
      when(() => mockAccount.displayName).thenReturn('User Display Name');
      when(() => mockAccount.authentication).thenReturn(mockAuth);
      when(() => mockAuth.idToken).thenReturn('fake_id_token');
      when(() => mockAccount.authorizationClient).thenReturn(mockAuthzClient);
      when(() => mockAuthzClient.authorizationForScopes(any())).thenAnswer((_) async => mockAuthz);
      when(() => mockAuthz.accessToken).thenReturn('fake_access_token');

      final result = await authService.signIn();

      expect(result, isNotNull);
      expect(result!.id, 'user_123');
      expect(result.email, 'user@example.com');
      expect(result.displayName, 'User Display Name');
      expect(result.idToken, 'fake_id_token');
      expect(result.accessToken, 'fake_access_token');

      expect(authService.currentUser, result);

      verify(() => mockGoogleSignIn.supportsAuthenticate()).called(1);
      verify(() => mockGoogleSignIn.authenticate()).called(1);
      verify(() => mockAuthzClient.authorizationForScopes(any())).called(1);
      verifyNever(() => mockAuthzClient.authorizeScopes(any()));
    });

    test('signIn returns GoogleAccount when auth succeeds but cached authz is null (requests new authz)', () async {
      when(() => mockGoogleSignIn.supportsAuthenticate()).thenReturn(true);
      when(() => mockGoogleSignIn.authenticate()).thenAnswer((_) async => mockAccount);
      when(() => mockAccount.id).thenReturn('user_123');
      when(() => mockAccount.email).thenReturn('user@example.com');
      when(() => mockAccount.displayName).thenReturn('User Display Name');
      when(() => mockAccount.authentication).thenReturn(mockAuth);
      when(() => mockAuth.idToken).thenReturn('fake_id_token');
      when(() => mockAccount.authorizationClient).thenReturn(mockAuthzClient);
      when(() => mockAuthzClient.authorizationForScopes(any())).thenAnswer((_) async => null);
      when(() => mockAuthzClient.authorizeScopes(any())).thenAnswer((_) async => mockAuthz);
      when(() => mockAuthz.accessToken).thenReturn('fake_access_token_new');

      final result = await authService.signIn();

      expect(result, isNotNull);
      expect(result!.accessToken, 'fake_access_token_new');
      expect(authService.currentUser, result);

      verify(() => mockGoogleSignIn.supportsAuthenticate()).called(1);
      verify(() => mockGoogleSignIn.authenticate()).called(1);
      verify(() => mockAuthzClient.authorizationForScopes(any())).called(1);
      verify(() => mockAuthzClient.authorizeScopes(any())).called(1);
    });

    test('signIn returns null and resets state on GoogleSignInException with canceled code', () async {
      when(() => mockGoogleSignIn.supportsAuthenticate()).thenReturn(true);
      when(() => mockGoogleSignIn.authenticate()).thenThrow(
        GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      );

      final result = await authService.signIn();

      expect(result, isNull);
      expect(authService.currentUser, isNull);
    });

    test('signIn rethrows GoogleSignInException with non-canceled code', () async {
      when(() => mockGoogleSignIn.supportsAuthenticate()).thenReturn(true);
      when(() => mockGoogleSignIn.authenticate()).thenThrow(
        GoogleSignInException(code: GoogleSignInExceptionCode.clientConfigurationError),
      );

      expect(() => authService.signIn(), throwsA(isA<GoogleSignInException>()));
    });

    test('signIn rethrows other errors and logs them', () async {
      when(() => mockGoogleSignIn.supportsAuthenticate()).thenReturn(true);
      when(() => mockGoogleSignIn.authenticate()).thenThrow(StateError('boom'));

      expect(() => authService.signIn(), throwsA(isA<StateError>()));
    });

    test('signOut calls signOut on GoogleSignIn and resets currentUser', () async {
      // Seed currentUser first
      when(() => mockGoogleSignIn.supportsAuthenticate()).thenReturn(true);
      when(() => mockGoogleSignIn.authenticate()).thenAnswer((_) async => mockAccount);
      when(() => mockAccount.id).thenReturn('user_123');
      when(() => mockAccount.email).thenReturn('user@example.com');
      when(() => mockAccount.displayName).thenReturn('User Display Name');
      when(() => mockAccount.authentication).thenReturn(mockAuth);
      when(() => mockAuth.idToken).thenReturn('fake_id_token');
      when(() => mockAccount.authorizationClient).thenReturn(mockAuthzClient);
      when(() => mockAuthzClient.authorizationForScopes(any())).thenAnswer((_) async => mockAuthz);
      when(() => mockAuthz.accessToken).thenReturn('fake_access_token');

      await authService.signIn();
      expect(authService.currentUser, isNotNull);

      // Now sign out
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async => mockAccount);

      await authService.signOut();

      expect(authService.currentUser, isNull);
      verify(() => mockGoogleSignIn.signOut()).called(1);
    });
  });
}
