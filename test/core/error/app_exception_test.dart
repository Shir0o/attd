import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/core/error/app_exception.dart';

void main() {
  group('AppException hierarchy', () {
    test('SyncException stores user message and technical details', () {
      final inner = Exception('SocketException: Connection refused');
      final exception = SyncException(
        userMessage: 'Unable to connect to Google Drive. Please check your internet connection.',
        recoverySuggestion: 'Check your Wi-Fi or cellular connection and retry.',
        technicalDetails: inner.toString(),
        isTransient: true,
      );

      expect(exception.userMessage, 'Unable to connect to Google Drive. Please check your internet connection.');
      expect(exception.recoverySuggestion, 'Check your Wi-Fi or cellular connection and retry.');
      expect(exception.technicalDetails, contains('Connection refused'));
      expect(exception.isTransient, isTrue);
      expect(exception.toString(), contains('SyncException'));
      expect(exception.toString(), contains('suggestion: Check your Wi-Fi'));
    });

    test('StorageException stores blocking failure details', () {
      const exception = StorageException(
        userMessage: 'Failed to restore backup file: Corrupted archive.',
        technicalDetails: 'ArchiveException: Invalid zip signature',
        isTransient: false,
      );

      expect(exception.userMessage, contains('Failed to restore backup file'));
      expect(exception.isTransient, isFalse);
    });

    test('AuthException models authentication failures', () {
      const exception = AuthException(
        userMessage: 'Sign in failed. Please try again.',
        technicalDetails: 'PlatformException: sign_in_canceled',
      );

      expect(exception.userMessage, 'Sign in failed. Please try again.');
      expect(exception.isTransient, isTrue);
    });
  });
}
