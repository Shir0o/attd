import 'package:flutter/material.dart';

import 'conv_theme.dart';

class ConvSegmentOption {
  const ConvSegmentOption({required this.label, this.icon});
  final String label;
  final IconData? icon;
}

/// Capsule segmented control — `.seg` in app.css.
class ConvSegmented extends StatelessWidget {
  const ConvSegmented({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<ConvSegmentOption> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            _SegButton(
              option: options[i],
              active: i == selectedIndex,
              onTap: () => onChanged(i),
            ),
            if (i < options.length - 1) const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  const _SegButton({
    required this.option,
    required this.active,
    required this.onTap,
  });
  final ConvSegmentOption option;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final fg = active ? c.ink : c.ink3;
    return Material(
      color: active ? c.card : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (option.icon != null) ...[
                Icon(option.icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                option.label,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
