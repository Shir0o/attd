class GoogleAccount {
  const GoogleAccount({
    required this.id,
    required this.email,
    this.displayName,
    this.idToken,
    this.accessToken,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? idToken;
  final String? accessToken;
}
