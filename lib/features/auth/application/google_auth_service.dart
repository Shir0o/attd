import '../domain/entities/google_account.dart';

abstract class GoogleAuthService {
  Future<GoogleAccount?> signIn();
  Future<void> signOut();
  GoogleAccount? get currentUser;
}
