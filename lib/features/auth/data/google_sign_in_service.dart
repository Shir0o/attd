import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/logging/app_logger.dart';
import '../application/google_auth_service.dart';
import '../domain/entities/google_account.dart';

final _log = AppLogger('GoogleSignIn');

/// Basic OAuth scopes used to obtain a usable access token alongside the
/// id token produced during authentication.
const List<String> _basicScopes = <String>['email', 'profile'];

class GoogleSignInAuthService implements GoogleAuthService {
  GoogleSignInAuthService({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  GoogleAccount? _currentUser;

  @override
  GoogleAccount? get currentUser => _currentUser;

  @override
  Future<GoogleAccount?> signIn() async {
    try {
      // v7: signIn() was split into authenticate() (interactive auth) and
      // authorizeScopes() (per-scope OAuth authorization).
      if (!_googleSignIn.supportsAuthenticate()) {
        return null;
      }
      final account = await _googleSignIn.authenticate();

      // Authorize basic scopes so we can return an accessToken too.
      var authz = await account.authorizationClient
          .authorizationForScopes(_basicScopes);
      authz ??= await account.authorizationClient.authorizeScopes(_basicScopes);

      // v7: account.authentication is now a synchronous getter that
      // returns only the idToken.
      final idToken = account.authentication.idToken;

      _currentUser = GoogleAccount(
        id: account.id,
        email: account.email,
        displayName: account.displayName,
        idToken: idToken,
        accessToken: authz.accessToken,
      );
      return _currentUser;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    } catch (error, stackTrace) {
      _log.warning('Google Sign-In Error', error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }
}
