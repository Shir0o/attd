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
    apiKey: 'AIzaSyAFdSoqYxiISIC2DxFE5dtEyQ0QfnhdSXo',
    appId: '1:995280441940:android:288d0afb940d4f29a2d3c1',
    messagingSenderId: '995280441940',
    projectId: 'attd-ef18a',
    storageBucket: 'attd-ef18a.firebasestorage.app',
  );

  static const FirebaseOptions _appleOptions = FirebaseOptions(
    apiKey: 'AIzaSyCIGT7YmrxIgRsXtQd29eCP2qg9Ou6PBTc',
    appId: '1:995280441940:ios:712f46ef7d1ae35ea2d3c1',
    messagingSenderId: '995280441940',
    projectId: 'attd-ef18a',
    storageBucket: 'attd-ef18a.firebasestorage.app',
    iosBundleId: 'com.attendance.tracker',
  );
}
