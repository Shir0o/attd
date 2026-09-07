/// Base class for all domain-specific application exceptions.
///
/// Encapsulates a sanitized, user-facing [userMessage] suitable for display
/// in the UI, alongside optional [technicalDetails] and an [isTransient] indicator
/// to inform whether the error should be surfaced as a transient notification
/// (e.g. snackbar) or a blocking dialog/view.
abstract class AppException implements Exception {
  const AppException({
    required this.userMessage,
    this.technicalDetails,
    this.isTransient = false,
  });

  /// User-friendly message explaining the issue and/or recovery action.
  final String userMessage;

  /// Technical diagnostic information (stripped of PII) for logging and reporting.
  final String? technicalDetails;

  /// Whether this failure is temporary (e.g. offline network hiccup)
  /// or blocking (e.g. corrupted file, security denial).
  final bool isTransient;

  @override
  String toString() {
    if (technicalDetails != null) {
      return '$runtimeType: $userMessage (details: $technicalDetails)';
    }
    return '$runtimeType: $userMessage';
  }
}

/// Thrown when remote synchronization (e.g. Google Drive sync) fails.
class SyncException extends AppException {
  const SyncException({
    required super.userMessage,
    super.technicalDetails,
    super.isTransient = true,
  });
}

/// Thrown when local or archive storage operations fail (e.g. corrupted backup).
class StorageException extends AppException {
  const StorageException({
    required super.userMessage,
    super.technicalDetails,
    super.isTransient = false,
  });
}

/// Thrown when authentication or authorization operations fail.
class AuthException extends AppException {
  const AuthException({
    required super.userMessage,
    super.technicalDetails,
    super.isTransient = true,
  });
}
