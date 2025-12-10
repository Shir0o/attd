import 'package:attendance_tracker/features/auth/data/firebase_auth_repository.dart';
import 'package:attendance_tracker/features/auth/domain/entities/credentials.dart';
import 'package:attendance_tracker/features/auth/domain/entities/google_account.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebaseAuthRepository', () {
    late MockFirebaseAuth firebaseAuth;
    late FakeFirebaseFirestore firestore;
    late FirebaseAuthRepository repository;

    setUp(() {
      firebaseAuth = MockFirebaseAuth();
      firestore = FakeFirebaseFirestore();
      repository = FirebaseAuthRepository(
        firebaseAuth: firebaseAuth,
        firestore: firestore,
      );
    });

    test('signs up with email and password and stores profile', () async {
      final user = await repository.signup(
        const Credentials(email: 'new@example.com', password: 'password123'),
      );

      expect(user.email, 'new@example.com');
      expect(firebaseAuth.currentUser, isNotNull);

      final snapshot = await firestore
          .collection('users')
          .doc(firebaseAuth.currentUser!.uid)
          .get();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data()!['email'], 'new@example.com');
    });

    test('logs in and prefers Firestore profile data', () async {
      final created = await firebaseAuth.createUserWithEmailAndPassword(
        email: 'demo@example.com',
        password: 'password123',
      );
      await firestore.collection('users').doc(created.user!.uid).set({
        'displayName': 'Firestore Name',
        'email': 'demo@example.com',
      });
      await firebaseAuth.signOut();

      final user = await repository.login(
        const Credentials(email: 'demo@example.com', password: 'password123'),
      );

      expect(user.displayName, 'Firestore Name');
      expect(firebaseAuth.currentUser, isNotNull);
    });

    test('signs in with Google credentials and persists profile', () async {
      final googleUser = MockUser(
        uid: 'google-uid',
        email: 'google@example.com',
        displayName: 'Google User',
      );
      firebaseAuth = MockFirebaseAuth(mockUser: googleUser);
      repository = FirebaseAuthRepository(
        firebaseAuth: firebaseAuth,
        firestore: firestore,
      );

      final user = await repository.loginWithGoogle(
        const GoogleAccount(
          id: 'google-uid',
          email: 'google@example.com',
          displayName: 'Google User',
          idToken: 'id-token',
          accessToken: 'access-token',
        ),
      );

      expect(user.email, 'google@example.com');
      expect(user.displayName, 'Google User');

      final snapshot = await firestore
          .collection('users')
          .doc('google-uid')
          .get();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data()!['displayName'], 'Google User');
    });

    test('restores existing Firebase session with profile data', () async {
      final signedInUser = MockUser(
        uid: 'existing',
        email: 'session@example.com',
        displayName: 'Session User',
      );
      firebaseAuth = MockFirebaseAuth(mockUser: signedInUser, signedIn: true);
      firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('existing').set({
        'displayName': 'Persisted Session',
        'email': 'session@example.com',
      });

      repository = FirebaseAuthRepository(
        firebaseAuth: firebaseAuth,
        firestore: firestore,
      );

      final user = await repository.currentUser();

      expect(user, isNotNull);
      expect(user!.displayName, 'Persisted Session');
      expect(user.email, 'session@example.com');
    });
  });
}
