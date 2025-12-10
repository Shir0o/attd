import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../domain/entities/credentials.dart';
import '../domain/entities/google_account.dart';
import '../domain/entities/user.dart' as domain;
import '../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required firebase_auth.FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
  }) : _auth = firebaseAuth,
       _firestore = firestore;

  final firebase_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Future<domain.User?> currentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    final displayName = await _loadDisplayName(firebaseUser);
    return _mapUser(firebaseUser, displayName: displayName);
  }

  @override
  Future<domain.User> login(Credentials credentials) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: credentials.email,
        password: credentials.password,
      );
      final user = credential.user;
      if (user == null) {
        throw AuthException('Login failed');
      }

      await _ensureProfileDocument(user);
      final displayName = await _loadDisplayName(user);
      return _mapUser(user, displayName: displayName);
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw AuthException(_mapAuthError(error));
    }
  }

  @override
  Future<domain.User> signup(Credentials credentials) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: credentials.email,
        password: credentials.password,
      );
      final user = credential.user;
      if (user == null) {
        throw AuthException('Account creation failed');
      }

      final fallbackDisplayName = credentials.email.split('@').first;
      await user.updateDisplayName(fallbackDisplayName);
      await _ensureProfileDocument(
        user,
        displayName: fallbackDisplayName,
        email: credentials.email,
      );

      return _mapUser(user, displayName: fallbackDisplayName);
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw AuthException(_mapAuthError(error));
    }
  }

  @override
  Future<domain.User> loginWithGoogle(GoogleAccount account) async {
    if (account.idToken == null && account.accessToken == null) {
      throw AuthException('Missing Google identity tokens');
    }

    final credential = firebase_auth.GoogleAuthProvider.credential(
      idToken: account.idToken,
      accessToken: account.accessToken,
    );

    try {
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw AuthException('Google sign-in failed');
      }

      await _ensureProfileDocument(
        user,
        displayName: account.displayName,
        email: account.email,
      );
      final displayName = await _loadDisplayName(user);
      return _mapUser(user, displayName: displayName);
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw AuthException(_mapAuthError(error));
    }
  }

  @override
  Future<void> logout() => _auth.signOut();

  Future<void> _ensureProfileDocument(
    firebase_auth.User? user, {
    String? displayName,
    String? email,
  }) async {
    if (user == null) return;

    final userEmail = email ?? user.email;
    try {
      await _firestore.collection('users').doc(user.uid).set({
        if (userEmail != null) 'email': userEmail,
        if (displayName != null) 'displayName': displayName,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<String?> _loadDisplayName(firebase_auth.User user) async {
    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      final data = snapshot.data();
      if (data != null) {
        final storedName = data['displayName'] as String?;
        if (storedName != null && storedName.trim().isNotEmpty) {
          return storedName.trim();
        }
      }
    } catch (_) {}
    return user.displayName ?? user.email;
  }

  String _mapAuthError(firebase_auth.FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Invalid email or password';
      case 'email-already-in-use':
        return 'An account with that email already exists';
      case 'weak-password':
        return 'Please choose a stronger password';
      default:
        return error.message ?? 'Authentication failed';
    }
  }

  domain.User _mapUser(firebase_auth.User firebaseUser, {String? displayName}) {
    final resolvedDisplayName =
        displayName ??
        firebaseUser.displayName ??
        firebaseUser.email ??
        firebaseUser.uid;
    return domain.User(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: resolvedDisplayName,
    );
  }
}
