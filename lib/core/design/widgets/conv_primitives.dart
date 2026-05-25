import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_radii.dart';
import '../app_shadows.dart';
import '../app_typography.dart';
import 'conv_theme.dart';

// ─────────────────────────────────────────────────────────────
// Tones
// ─────────────────────────────────────────────────────────────
enum ConvTone { neutral, present, absent }

extension on ConvTone {
  Color foreground(ConvocationColors c) => switch (this) {
    ConvTone.present => c.present,
    ConvTone.absent => c.absent,
    ConvTone.neutral => c.ink2,
  };

  Color soft(ConvocationColors c) {
    final fg = foreground(c);
    return this == ConvTone.neutral
        ? c.cardSoft
        : Color.alphaBlend(fg.withValues(alpha: 0.18), c.card);
  }
}

// ─────────────────────────────────────────────────────────────
// Avatar — letter, optional tone
// ─────────────────────────────────────────────────────────────
class ConvAvatar extends StatelessWidget {
  const ConvAvatar({
    super.key,
    required this.letter,
    this.size = 40,
    this.tone = ConvTone.neutral,
  });

  final String letter;
  final double size;
  final ConvTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final fg = switch (tone) {
      ConvTone.present => c.present,
      ConvTone.absent => c.absent,
      ConvTone.neutral => c.primary,
    };
    final bg = switch (tone) {
      ConvTone.present => Color.alphaBlend(
        c.present.withValues(alpha: 0.18),
        c.card,
      ),
      ConvTone.absent => Color.alphaBlend(
        c.absent.withValues(alpha: 0.18),
        c.card,
      ),
      ConvTone.neutral => c.cardSoft,
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        letter,
        style: AppTypography.fraunces(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Pill — capsule chip, optional leading icon, on/off variants
// ─────────────────────────────────────────────────────────────
class ConvPill extends StatelessWidget {
  const ConvPill({
    super.key,
    required this.label,
    this.leading,
    this.onTap,
    this.isOn = false,
    this.ghost = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    this.fontSize = 13,
    this.letterSpacing,
  });

  final String label;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool isOn;
  final bool ghost;
  final EdgeInsets padding;
  final double fontSize;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final fg = isOn
        ? c.onPrimary
        : ghost
        ? c.ink2
        : c.ink;
    final bg = isOn
        ? c.primary
        : ghost
        ? Colors.transparent
        : c.cardSoft;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[
          IconTheme(
            data: IconThemeData(color: fg, size: fontSize + 1),
            child: leading!,
          ),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            letterSpacing: letterSpacing,
          ),
        ),
      ],
    );
    final child = Padding(padding: padding, child: content);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: onTap == null
          ? child
          : InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onTap,
              child: child,
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Stamp — postcard stamp with rotation
// ─────────────────────────────────────────────────────────────
class ConvStamp extends StatelessWidget {
  const ConvStamp({
    super.key,
    required this.label,
    required this.tone,
  });

  final String label;
  final ConvTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final color = tone.foreground(c);
    final angle = tone == ConvTone.present ? -0.1 : 0.14;
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.fraunces(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.32,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Day chip — 28px circle S/M/T/W/T/F/S
// ─────────────────────────────────────────────────────────────
class ConvDayChip extends StatelessWidget {
  const ConvDayChip({
    super.key,
    required this.day,
    required this.active,
    this.onTap,
    this.size = 28,
  });

  final String day;
  final bool active;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final bg = active ? c.primary : c.cardSoft;
    final fg = active ? c.onPrimary : c.ink3;
    return Material(
      color: bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Toggle — 56×32 inline present/absent toggle
// ─────────────────────────────────────────────────────────────
class ConvToggle extends StatelessWidget {
  const ConvToggle({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 56,
        height: 32,
        decoration: BoxDecoration(
          color: value
              ? Color.alphaBlend(c.present.withValues(alpha: 0.3), c.bg)
              : c.bg3,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: const Cubic(0.2, 0.7, 0.3, 1.0),
              alignment: value
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: value ? c.present : c.ink4,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Stat chip — Present/Absent/Total tile
// ─────────────────────────────────────────────────────────────
class ConvStatChip extends StatelessWidget {
  const ConvStatChip({
    super.key,
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final ConvTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final fg = tone.foreground(c);
    final bg = tone.soft(c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadii.compactR),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.eyebrow(
              color: fg.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.displayNumber(fontSize: 28, color: fg),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Section label — eyebrow with leading 3×12 bar
// ─────────────────────────────────────────────────────────────
class ConvSectionLabel extends StatelessWidget {
  const ConvSectionLabel({
    super.key,
    required this.label,
    this.tone = ConvTone.neutral,
    this.topPadding = 12,
  });

  final String label;
  final ConvTone tone;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final color = switch (tone) {
      ConvTone.present => c.present,
      ConvTone.absent => c.absent,
      ConvTone.neutral => c.ink3,
    };
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: 4, left: 4, right: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(label.toUpperCase(), style: AppTypography.eyebrow(color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Card primitives
// ─────────────────────────────────────────────────────────────
class ConvCard extends StatelessWidget {
  const ConvCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.margin,
    this.elevated = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final bool elevated;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: AppRadii.cardR,
        boxShadow: elevated ? AppShadows.card : null,
      ),
      child: Material(
        color: c.card,
        borderRadius: AppRadii.cardR,
        clipBehavior: onTap != null ? Clip.antiAlias : Clip.none,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class ConvCardSoft extends StatelessWidget {
  const ConvCardSoft({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Container(
      margin: margin,
      child: Material(
        color: c.cardSoft,
        borderRadius: AppRadii.softR,
        clipBehavior: onTap != null ? Clip.antiAlias : Clip.none,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FAB — 60×60 squircle with primary glow
// ─────────────────────────────────────────────────────────────
class ConvFab extends StatelessWidget {
  const ConvFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final btn = Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: c.primary,
        borderRadius: AppRadii.fabR,
        boxShadow: AppShadows.fab(c.primary),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.fabR,
          onTap: onPressed,
          child: Icon(icon, color: c.onPrimary, size: 26),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

// ─────────────────────────────────────────────────────────────
// Eyebrow text helper
// ─────────────────────────────────────────────────────────────
class ConvEyebrow extends StatelessWidget {
  const ConvEyebrow(this.text, {super.key, this.color, this.fontSize = 11});

  final String text;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Text(
      text.toUpperCase(),
      style: AppTypography.eyebrow(
        color: color ?? c.ink3,
        fontSize: fontSize,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Icon button (40×40 round)
// ─────────────────────────────────────────────────────────────
class ConvIconButton extends StatelessWidget {
  const ConvIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 40,
    this.color,
    this.iconSize = 22,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Icon(icon, size: iconSize, color: color ?? c.ink),
        ),
      ),
    );
  }
}
