import 'package:google_sign_in/google_sign_in.dart';

import '../application/google_auth_service.dart';
import '../domain/entities/google_account.dart';

class GoogleSignInAuthService implements GoogleAuthService {
  GoogleSignInAuthService({required GoogleSignIn googleSignIn})
    : _googleSignIn = googleSignIn;

  final GoogleSignIn _googleSignIn;

  @override
  Future<GoogleAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final auth = await account.authentication;
      return GoogleAccount(
        id: account.id,
        email: account.email,
        displayName: account.displayName,
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
    } catch (error, stackTrace) {
      print('Google Sign-In Error: $error');
      print(stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> signOut() => _googleSignIn.signOut();
}
