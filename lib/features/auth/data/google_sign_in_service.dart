import 'package:google_sign_in/google_sign_in.dart';

import '../application/google_auth_service.dart';
import '../domain/entities/google_account.dart';

class GoogleSignInAuthService implements GoogleAuthService {
  GoogleSignInAuthService({required GoogleSignIn googleSignIn})
    : _googleSignIn = googleSignIn;

  final GoogleSignIn _googleSignIn;
  GoogleAccount? _currentUser;

  @override
  GoogleAccount? get currentUser => _currentUser;

  @override
  Future<GoogleAccount?> signIn() async {
    try {
      final account = await _googleSignIn.authenticate();
      
      final auth = account.authentication;
      final authorization = await account.authorizationClient.authorizeScopes(['email']);
      
      _currentUser = GoogleAccount(
        id: account.id,
        email: account.email,
        displayName: account.displayName,
        idToken: auth.idToken,
        accessToken: authorization.accessToken,
      );
      return _currentUser;
    } catch (error, stackTrace) {
      print('Google Sign-In Error: $error');
      print(stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }
}
