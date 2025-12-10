import 'package:uuid/uuid.dart';

import '../domain/entities/credentials.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/auth_repository.dart';
import 'local_auth_storage.dart';

class LocalAuthDataSource {
  LocalAuthDataSource(this.storage);

  final LocalAuthStorage storage;
  final _uuid = const Uuid();

  Future<bool> userExists(String username) async {
    final user = await storage.findUserByUsername(username);
    return user != null;
  }

  Future<User> createUser(Credentials credentials) async {
    final id = _uuid.v4();
    await storage.saveUser(credentials, id: id);
    return User(id: id, username: credentials.username);
  }

  Future<User> authenticate(Credentials credentials) async {
    final stored = await storage.findUserByUsername(credentials.username);
    if (stored == null || stored.password != credentials.password) {
      throw AuthException('Invalid username or password');
    }
    return User(id: stored.id, username: stored.username);
  }

  Future<void> persistSession(User user) => storage.persistSession(user);

  Future<User?> loadSession() => storage.loadSession();

  Future<void> clearSession() => storage.clearSession();
}
