import 'package:flutter/material.dart';

/// The one short explainer shown before the share sheet opens. Resolves true
/// when the owner chooses to go on.
Future<bool> showHandoffExplainer(
  BuildContext context, {
  required String eventTitle,
}) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Hand off this session'),
      content: Text(
        'This makes a plain, unencrypted file with only the event name, the '
        'date and the roster names of "$eventTitle". Send it to someone you '
        'trust; they mark attendance in this app and send a file back for '
        'you to open.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('handoffExplainerContinue'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Choose how to send'),
        ),
      ],
    ),
  );
  return go ?? false;
}
