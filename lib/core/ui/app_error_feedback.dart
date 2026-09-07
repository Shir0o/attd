import 'package:flutter/material.dart';
import '../design/app_typography.dart';
import '../design/widgets/conv_theme.dart';

/// Centralized UI helper for displaying error feedback adhering to the
/// Convocation design principles (tonal shifts, pill shapes, soft shadows).
class AppErrorFeedback {
  AppErrorFeedback._();

  /// Creates a Convocation styled error widget to replace Flutter's default red/grey screen.
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
    final c = context.conv;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        backgroundColor: c.absent.withValues(alpha: 0.92),
        content: Text(
          message,
          style: AppTypography.geist(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        action: onRetry != null
            ? SnackBarAction(
                label: retryLabel,
                textColor: Colors.white,
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
    final c = context.conv;

    await showAdaptiveDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: c.card,
          title: Text(
            title,
            style: AppTypography.fraunces(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
          content: Text(
            message,
            style: AppTypography.geist(
              fontSize: 14,
              color: c.ink2,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dismissLabel, style: AppTypography.geist(color: c.ink2)),
            ),
            if (onRetry != null)
              FilledButton(
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  backgroundColor: c.primary,
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onRetry();
                },
                child: Text(retryLabel, style: AppTypography.geist(color: c.onPrimary)),
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
    final c = context.conv;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.absent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: c.absent,
              ),
            ),
            const SizedBox(height: 16),
            if (title != null) ...[
              Text(
                title!,
                style: AppTypography.fraunces(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              message,
              style: AppTypography.geist(
                fontSize: 14,
                color: c.ink2,
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
