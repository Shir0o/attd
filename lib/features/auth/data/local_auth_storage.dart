import 'dart:convert';
import 'dart:io';

import '../domain/entities/credentials.dart';
import '../domain/entities/user.dart';

class LocalAuthStorage {
  LocalAuthStorage({required this.directoryProvider});

  final Future<Directory> Function() directoryProvider;

  static const _fileName = 'auth_store.json';

  Future<File> _resolveFile() async {
    final directory = await directoryProvider();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final file = File('${directory.path}/$_fileName');
    if (!await file.exists()) {
      await file.writeAsString(jsonEncode({'users': [], 'session': null}));
    }
    return file;
  }

  Future<Map<String, dynamic>> _read() async {
    final file = await _resolveFile();
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  Future<void> _write(Map<String, dynamic> data) async {
    final file = await _resolveFile();
    await file.writeAsString(jsonEncode(data));
  }

  Future<List<_StoredUser>> loadUsers() async {
    final data = await _read();
    final users = (data['users'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(_StoredUser.fromJson)
        .toList();
    return users;
  }

  Future<void> saveUsers(List<_StoredUser> users) async {
    final data = await _read();
    data['users'] = users.map((user) => user.toJson()).toList();
    await _write(data);
  }

  Future<_StoredUser?> loadUserById(String id) async {
    final users = await loadUsers();
    try {
      return users.firstWhere((user) => user.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> persistSession(User user) async {
    final data = await _read();
    data['session'] = user.id;
    await _write(data);
  }

  Future<User?> loadSession() async {
    final data = await _read();
    final sessionId = data['session'] as String?;
    if (sessionId == null) return null;
    final storedUser = await loadUserById(sessionId);
    if (storedUser == null) return null;
    return User(id: storedUser.id, username: storedUser.username);
  }

  Future<void> clearSession() async {
    final data = await _read();
    data['session'] = null;
    await _write(data);
  }

  Future<void> saveUser(Credentials credentials, {required String id}) async {
    final users = await loadUsers();
    users.removeWhere((user) => user.username == credentials.username);
    users.add(
      _StoredUser(
        id: id,
        username: credentials.username,
        password: credentials.password,
      ),
    );
    await saveUsers(users);
  }

  Future<_StoredUser?> findUserByUsername(String username) async {
    final users = await loadUsers();
    try {
      return users.firstWhere((user) => user.username == username);
    } catch (_) {
      return null;
    }
  }
}

class _StoredUser {
  const _StoredUser({
    required this.id,
    required this.username,
    required this.password,
  });

  final String id;
  final String username;
  final String password;

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'password': password,
  };

  static _StoredUser fromJson(Map<String, dynamic> json) {
    return _StoredUser(
      id: json['id'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
    );
  }
}
