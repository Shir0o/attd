import 'package:attendance_tracker/features/auth/config/google_oauth_config.dart';
import 'package:attendance_tracker/features/auth/domain/entities/credentials.dart';
import 'package:attendance_tracker/features/auth/domain/entities/google_account.dart';
import 'package:attendance_tracker/features/auth/domain/entities/user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth value objects expose constructor values', () {
    const credentials = Credentials(
      email: 'person@example.com',
      password: 'secret',
    );
    const account = GoogleAccount(
      id: 'google-id',
      email: 'person@example.com',
      displayName: 'Person',
      idToken: 'id-token',
      accessToken: 'access-token',
    );

    expect(credentials.email, 'person@example.com');
    expect(credentials.password, 'secret');
    expect(account.id, 'google-id');
    expect(account.displayName, 'Person');
    expect(account.idToken, 'id-token');
    expect(account.accessToken, 'access-token');
  });

  test('User resolves display name and copyWith values', () {
    const named = User(
      id: 'u1',
      email: 'person@example.com',
      displayName: 'Person',
    );
    const unnamed = User(id: 'u2', email: 'fallback@example.com');

    expect(named.resolvedName, 'Person');
    expect(unnamed.resolvedName, 'fallback@example.com');
    expect(named.copyWith(email: 'new@example.com').email, 'new@example.com');
    expect(named.copyWith(displayName: 'New Name').resolvedName, 'New Name');
  });

  test('GoogleOAuthConfig reads dotenv values', () {
    dotenv.loadFromString(
      envString: '''
GOOGLE_ANDROID_CLIENT_ID=android-id
GOOGLE_IOS_CLIENT_ID=ios-id
GOOGLE_WEB_CLIENT_ID=web-id
''',
    );

    expect(GoogleOAuthConfig.androidServerClientId, 'android-id');
    expect(GoogleOAuthConfig.iosClientId, 'ios-id');
    expect(GoogleOAuthConfig.webServerClientId, 'web-id');
  });
}
