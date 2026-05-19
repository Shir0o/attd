import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleOAuthConfig {
  static String get androidServerClientId => dotenv.get('GOOGLE_ANDROID_CLIENT_ID', fallback: '');
  static String get iosClientId => dotenv.get('GOOGLE_IOS_CLIENT_ID', fallback: '');
  static String get webServerClientId => dotenv.get('GOOGLE_WEB_CLIENT_ID', fallback: '');
  static int get googleCloudProjectNumber => int.tryParse(dotenv.get('GOOGLE_CLOUD_PROJECT_NUMBER', fallback: '0')) ?? 0;
}
