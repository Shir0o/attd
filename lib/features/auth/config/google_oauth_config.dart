class GoogleOAuthConfig {
  static const androidServerClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_CLIENT_ID',
    defaultValue: 'YOUR_ANDROID_CLIENT_ID.apps.googleusercontent.com',
  );

  static const iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: 'com.googleusercontent.apps.YOUR_IOS_CLIENT_ID',
  );
}
