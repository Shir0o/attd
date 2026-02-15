import '../domain/entities/credentials.dart';
import '../domain/entities/google_account.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/auth_repository.dart';

class LocalAuthRepository implements AuthRepository {
  static const _localUser = User(
    id: 'local-user',
    email: 'local@device',
    displayName: 'Local User',
  );

  @override
  Future<User> login(Credentials credentials) async => _localUser;

  @override
  Future<User> signup(Credentials credentials) async => _localUser;

  @override
  Future<User> loginWithGoogle(GoogleAccount account) async => _localUser;

  @override
  Future<void> logout() async {}

  @override
  Future<User?> currentUser() async => _localUser;
}
