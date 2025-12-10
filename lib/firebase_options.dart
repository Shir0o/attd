import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return _webOptions;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidOptions;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _appleOptions;
      default:
        return _webOptions;
    }
  }

  static const FirebaseOptions _webOptions = FirebaseOptions(
    apiKey: 'test-api-key',
    appId: '1:000000000000:web:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-project',
    authDomain: 'demo.firebaseapp.com',
    storageBucket: 'demo.appspot.com',
  );

  static const FirebaseOptions _androidOptions = FirebaseOptions(
    apiKey: 'test-api-key',
    appId: '1:000000000000:android:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-project',
    storageBucket: 'demo.appspot.com',
  );

  static const FirebaseOptions _appleOptions = FirebaseOptions(
    apiKey: 'test-api-key',
    appId: '1:000000000000:ios:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-project',
    storageBucket: 'demo.appspot.com',
    iosBundleId: 'com.example.attendanceTracker',
  );
}
