import 'package:flutter/material.dart';
import 'crash_reporting_service.dart';

/// Modal dialog prompting the user on first launch for crash reporting consent.
class CrashReportingConsentDialog {
  CrashReportingConsentDialog._();

  /// Prompts the user on first app launch if consent hasn't been asked yet.
  static Future<void> promptIfNeeded(
    BuildContext context, {
    required CrashReportingService service,
  }) async {
    if (service.hasAskedConsent) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showAdaptiveDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: colorScheme.surface,
          title: Text(
            'Help improve Attendance?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          content: Text(
            'Send anonymous crash diagnostics and error reports when something goes wrong. '
            'No names, emails, or roster records are ever shared. You can change this at any time in Settings.',
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
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await service.setCollectionEnabled(false);
              },
              child: const Text('No thanks'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await service.setCollectionEnabled(true);
              },
              child: const Text('Agree & Share'),
            ),
          ],
        );
      },
    );
  }
}
