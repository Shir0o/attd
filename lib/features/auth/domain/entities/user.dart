class User {
  const User({required this.id, required this.username});

  final String id;
  final String username;

  User copyWith({String? id, String? username}) {
    return User(id: id ?? this.id, username: username ?? this.username);
  }
}
