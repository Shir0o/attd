import 'package:flutter/material.dart';

import '../models/marking_mode.dart';

/// Bottom sheet picker for choosing an event's fast marking mode preset.
Future<MarkingMode?> showFastMarkingModePicker(
  BuildContext context, {
  MarkingMode? initial,
}) {
  return showModalBottomSheet<MarkingMode>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _FastMarkingModeSheet(
      initial: initial ?? kDefaultMarkingMode,
    ),
  );
}

class _FastMarkingModeSheet extends StatefulWidget {
  const _FastMarkingModeSheet({required this.initial});

  final MarkingMode initial;

  @override
  State<_FastMarkingModeSheet> createState() => _FastMarkingModeSheetState();
}

class _FastMarkingModeSheetState extends State<_FastMarkingModeSheet> {
  late MarkingMode _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fast Marking Mode',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose the fast marking surface shown alongside Deck and List during attendance.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final mode in MarkingMode.values) ...[
              _ModeTile(
                key: Key('marking_mode_option_${mode.name}'),
                label: mode.label,
                description: mode.hint,
                selected: _selected == mode,
                onTap: () => setState(() => _selected = mode),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('markingModeConfirmButton'),
                onPressed: () => Navigator.of(context).pop(_selected),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    super.key,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderColor =
        selected ? colorScheme.primary : colorScheme.outlineVariant;
    final bg = selected
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : colorScheme.surface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
