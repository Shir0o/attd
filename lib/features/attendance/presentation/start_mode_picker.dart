import 'package:flutter/material.dart';

import '../models/attendance_start_mode.dart';

/// Shows a modal sheet asking the user how to pre-seed a new session.
///
/// Returns the picked mode, or `null` if the user dismissed the sheet.
Future<AttendanceStartMode?> showStartModePicker(
  BuildContext context, {
  AttendanceStartMode? initial,
}) {
  final selected = initial ?? AttendanceStartMode.allAbsent;
  return showModalBottomSheet<AttendanceStartMode>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _StartModePickerSheet(initial: selected),
  );
}

class _StartModePickerSheet extends StatefulWidget {
  const _StartModePickerSheet({required this.initial});

  final AttendanceStartMode initial;

  @override
  State<_StartModePickerSheet> createState() => _StartModePickerSheetState();
}

class _StartModePickerSheetState extends State<_StartModePickerSheet> {
  late AttendanceStartMode _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Start attendance',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose a starting status for everyone. You can change individual people after.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final mode in AttendanceStartMode.values)
              Padding(
                key: ValueKey('start_mode_${mode.name}'),
                padding: const EdgeInsets.only(bottom: 8),
                child: _ModeTile(
                  mode: mode,
                  selected: _selected == mode,
                  onTap: () => setState(() => _selected = mode),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('startModeConfirmButton'),
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('Start'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final AttendanceStartMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderColor = selected ? colorScheme.primary : colorScheme.outlineVariant;
    final bg = selected
        ? colorScheme.primaryContainer.withValues(alpha: 0.4)
        : colorScheme.surfaceContainerLow;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: selected ? Border.all(color: borderColor, width: 2) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
