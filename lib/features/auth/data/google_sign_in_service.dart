import 'package:google_sign_in/google_sign_in.dart';

import '../application/google_auth_service.dart';
import '../domain/entities/google_account.dart';

class GoogleSignInAuthService implements GoogleAuthService {
  GoogleSignInAuthService({required GoogleSignIn googleSignIn})
    : _googleSignIn = googleSignIn;

  final GoogleSignIn _googleSignIn;

  @override
  Future<GoogleAccount?> signIn() async {
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
  }

  @override
  Future<void> signOut() => _googleSignIn.signOut();
}
