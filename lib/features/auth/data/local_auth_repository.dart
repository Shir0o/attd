import '../domain/entities/credentials.dart';
import '../domain/entities/google_account.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/auth_repository.dart';
import 'local_auth_data_source.dart';

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this.dataSource);

  final LocalAuthDataSource dataSource;

  @override
  Future<User?> currentUser() => dataSource.loadSession();

  @override
  Future<User> login(Credentials credentials) async {
    final user = await dataSource.authenticate(credentials);
    await dataSource.persistSession(user);
    return user;
  }

  @override
  Future<void> logout() => dataSource.clearSession();

  @override
  Future<User> signup(Credentials credentials) async {
    final exists = await dataSource.userExists(credentials.username);
    if (exists) {
      throw AuthException('User already exists');
    }
    final user = await dataSource.createUser(credentials);
    await dataSource.persistSession(user);
    return user;
  }

  @override
  Future<User> loginWithGoogle(GoogleAccount account) async {
    final user = await dataSource.authenticateGoogle(account);
    await dataSource.persistSession(user);
    return user;
  }
}
