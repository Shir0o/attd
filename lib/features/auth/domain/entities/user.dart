class User {
  const User({required this.id, required this.email, this.displayName});

  final String id;
  final String email;
  final String? displayName;

  String get resolvedName =>
      displayName?.isNotEmpty == true ? displayName! : email;

  User copyWith({String? id, String? email, String? displayName}) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }
}
