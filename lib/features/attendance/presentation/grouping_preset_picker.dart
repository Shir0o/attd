import 'package:flutter/material.dart';

import '../models/roster_grouping.dart';

/// Asked **once**, the first time attendance is taken for an event whose
/// grouping preset hasn't been chosen yet. Returns the picked grouping, or
/// `null` if the user dismissed the sheet.
///
/// The choice is saved on the event and inherited on later sessions; it can be
/// changed afterwards in the event editor ("Group roster by"). The sheet shows
/// that hint so the one-time prompt doesn't feel like a dead end.
Future<RosterGrouping?> showGroupingPresetPicker(
  BuildContext context, {
  RosterGrouping initial = RosterGrouping.byStatus,
}) {
  return showModalBottomSheet<RosterGrouping>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _GroupingPresetSheet(initial: initial),
  );
}

class _GroupingPresetSheet extends StatefulWidget {
  const _GroupingPresetSheet({required this.initial});

  final RosterGrouping initial;

  @override
  State<_GroupingPresetSheet> createState() => _GroupingPresetSheetState();
}

class _GroupingPresetSheetState extends State<_GroupingPresetSheet> {
  late RosterGrouping _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Group the roster by',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how people are grouped while you take attendance for this event.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _GroupingTile(
              key: const Key('grouping_byStatus'),
              icon: Icons.checklist_rounded,
              label: 'Status',
              description: 'Present and absent in separate sections.',
              selected: _selected == RosterGrouping.byStatus,
              onTap: () =>
                  setState(() => _selected = RosterGrouping.byStatus),
            ),
            const SizedBox(height: 8),
            _GroupingTile(
              key: const Key('grouping_byFamily'),
              icon: Icons.groups_outlined,
              label: 'Family',
              description: 'Households grouped together.',
              selected: _selected == RosterGrouping.byFamily,
              onTap: () =>
                  setState(() => _selected = RosterGrouping.byFamily),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You can change this anytime in the event settings.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('groupingConfirmButton'),
                onPressed: () => Navigator.of(context).pop(_selected),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupingTile extends StatelessWidget {
  const _GroupingTile({
    super.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
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
          children: [
            Icon(
              icon,
              color:
                  selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
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
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color:
                  selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
