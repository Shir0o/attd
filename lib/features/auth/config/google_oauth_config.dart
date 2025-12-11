class GoogleOAuthConfig {
  static const androidServerClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_CLIENT_ID',
    defaultValue: '995280441940-603pbogfltv1de3hknr8iae0jqcsrk8p.apps.googleusercontent.com',
  );

  static const iosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '995280441940-83dh1gfp7likmlkmnqutsd9n7pidtis3.apps.googleusercontent.com',
  );

  static const webServerClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '995280441940-ljd5jupgd8ak2hirfn4q9vh4n5ungbf6.apps.googleusercontent.com',
  );
}
