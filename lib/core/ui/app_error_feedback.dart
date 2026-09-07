import 'package:flutter/material.dart';

/// Centralized UI helper for displaying error feedback adhering to the
/// Fluid Humanist design principles (tonal shifts, pill shapes, soft shadows).
class AppErrorFeedback {
  AppErrorFeedback._();

  /// Creates a Fluid Humanist styled error widget to replace Flutter's default red/grey screen.
  static Widget buildErrorWidget(FlutterErrorDetails details) {
    return Material(
      color: Colors.transparent,
      child: AppErrorView(
        title: 'Something went wrong',
        message: 'An unexpected application error occurred.',
        technicalDetails: details.exceptionAsString(),
      ),
    );
  }

  /// Displays a transient, non-blocking notification via a styled pill SnackBar.
  static void showSnackBar(
    BuildContext context, {
    required String message,
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
    Duration duration = const Duration(seconds: 4),
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        backgroundColor: colorScheme.errorContainer,
        content: Text(
          message,
          style: TextStyle(
            color: colorScheme.onErrorContainer,
            fontWeight: FontWeight.w500,
          ),
        ),
        action: onRetry != null
            ? SnackBarAction(
                label: retryLabel,
                textColor: colorScheme.onErrorContainer,
                onPressed: onRetry,
              )
            : null,
        duration: duration,
      ),
    );
  }

  /// Displays a modal recovery dialog for blocking failures that require
  /// explicit user acknowledgment or action.
  static Future<void> showDialog(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
    String dismissLabel = 'Dismiss',
  }) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showAdaptiveDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: colorScheme.surface,
          title: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          content: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dismissLabel),
            ),
            if (onRetry != null)
              FilledButton(
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onRetry();
                },
                child: Text(retryLabel),
              ),
          ],
        );
      },
    );
  }
}

/// An inline state widget replacing failed content with an explanatory message and retry action.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.message,
    this.title,
    this.technicalDetails,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  final String? title;
  final String message;
  final String? technicalDetails;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            if (title != null) ...[
              Text(
                title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: onRetry,
                child: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A boundary widget that safely catches building/rendering errors in child builders.
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    super.key,
    required this.builder,
    this.fallbackTitle = 'Something went wrong',
    this.fallbackMessage = 'An unexpected view error occurred.',
    this.onRetry,
  });

  final WidgetBuilder builder;
  final String fallbackTitle;
  final String fallbackMessage;
  final VoidCallback? onRetry;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return AppErrorView(
        title: widget.fallbackTitle,
        message: widget.fallbackMessage,
        onRetry: () {
          setState(() {
            _error = null;
          });
          widget.onRetry?.call();
        },
      );
    }

    try {
      return widget.builder(context);
    } catch (e) {
      return AppErrorView(
        title: widget.fallbackTitle,
        message: widget.fallbackMessage,
        onRetry: () {
          setState(() {
            _error = null;
          });
          widget.onRetry?.call();
        },
      );
    }
  }
}
