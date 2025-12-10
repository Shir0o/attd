import '../entities/credentials.dart';
import '../entities/google_account.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<User> login(Credentials credentials);
  Future<User> signup(Credentials credentials);
  Future<User> loginWithGoogle(GoogleAccount account);
  Future<void> logout();
  Future<User?> currentUser();
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
