import 'package:flutter/material.dart';

import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_primitives.dart';
import '../../../core/design/widgets/conv_theme.dart';

// ─────────────────────────────────────────────────────────────
// Onboarding editorial art widgets (mirror screens.jsx 545–709)
// ─────────────────────────────────────────────────────────────

/// Overlapping member cards with rotating present/absent stamps.
class OnboardingDeckArt extends StatelessWidget {
  const OnboardingDeckArt({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Back card — fanned left, Absent stamp on its top-left corner.
          Transform.translate(
            offset: const Offset(-30, 0),
            child: Transform.rotate(
              angle: -0.122, // -7°
              child: const _DeckCard(
                letter: 'J',
                name: 'Jane Smith',
                tone: ConvTone.absent,
                width: 168,
                height: 222,
                avatarSize: 62,
                nameSize: 17,
                stampLabel: 'Absent',
                stampAlignment: Alignment.topLeft,
              ),
            ),
          ),
          // Front card — fanned right, Present stamp on its top-right corner.
          Transform.translate(
            offset: const Offset(28, 0),
            child: Transform.rotate(
              angle: 0.087, // 5°
              child: const _DeckCard(
                letter: 'J',
                name: 'John Doe',
                tone: ConvTone.present,
                width: 192,
                height: 250,
                avatarSize: 78,
                nameSize: 22,
                stampLabel: 'Present',
                stampAlignment: Alignment.topRight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.letter,
    required this.name,
    required this.tone,
    required this.width,
    required this.height,
    required this.avatarSize,
    required this.nameSize,
    required this.stampLabel,
    required this.stampAlignment,
  });

  final String letter;
  final String name;
  final ConvTone tone;
  final double width;
  final double height;
  final double avatarSize;
  final double nameSize;
  final String stampLabel;
  final Alignment stampAlignment;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final stampOnLeft = stampAlignment == Alignment.topLeft;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Positioned.fill forces the card to the fixed SizedBox size, while
          // FittedBox keeps the content from overflowing under large
          // accessibility text scales.
          Positioned.fill(
            child: ConvCard(
              padding: const EdgeInsets.all(18),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConvAvatar(letter: letter, size: avatarSize, tone: tone),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: AppTypography.fraunces(
                          fontSize: nameSize,
                          fontWeight: FontWeight.w500,
                          color: c.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: stampOnLeft ? 14 : null,
            right: stampOnLeft ? null : 14,
            child: ConvStamp(label: stampLabel, tone: tone),
          ),
        ],
      ),
    );
  }
}

/// Cascading session cards with a small translateX offset per row.
class OnboardingHistoryArt extends StatelessWidget {
  const OnboardingHistoryArt({super.key});

  static const _sessions = [
    (date: 'Mar 29', dow: 'Sunday · 10:00 AM', present: 42, absent: 3),
    (date: 'Mar 25', dow: 'Wednesday · 7:00 PM', present: 28, absent: 14),
    (date: 'Mar 20', dow: 'Friday · 6:30 PM', present: 35, absent: 5),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return SizedBox(
      width: 290,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _sessions.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Transform.translate(
              offset: Offset(i * 6.0, 0),
              child: ConvCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _sessions[i].date,
                            style: AppTypography.fraunces(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _sessions[i].dow,
                            style: AppTypography.geist(
                                fontSize: 11, color: c.ink3),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${_sessions[i].present}',
                          style: AppTypography.displayNumber(
                            fontSize: 20,
                            color: c.present,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '·',
                            style: AppTypography.geist(
                                fontSize: 16, color: c.ink4),
                          ),
                        ),
                        Text(
                          '${_sessions[i].absent}',
                          style: AppTypography.displayNumber(
                            fontSize: 20,
                            color: c.absent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Family card with member chips, plus a loner card below.
class OnboardingFamilyArt extends StatelessWidget {
  const OnboardingFamilyArt({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return SizedBox(
      width: 290,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConvCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.family_restroom,
                          color: c.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smith',
                          style: AppTypography.fraunces(
                            fontSize: 19,
                            fontWeight: FontWeight.w500,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '4 members',
                          style:
                              AppTypography.geist(fontSize: 11, color: c.ink3),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final n in ['Alice', 'Bob', 'Liam', 'Mia'])
                      _MemberChip(name: n),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Transform.translate(
            offset: const Offset(14, 0),
            child: ConvCardSoft(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const ConvAvatar(letter: 'D', size: 36),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dan Solo',
                        style: AppTypography.geist(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Loner',
                        style:
                            AppTypography.geist(fontSize: 11, color: c.ink3),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(
        color: c.cardSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConvAvatar(letter: name[0], size: 22),
          const SizedBox(width: 6),
          Text(
            name,
            style: AppTypography.geist(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: c.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary-tinted cloud icon with a sync status card below.
class OnboardingCloudArt extends StatelessWidget {
  const OnboardingCloudArt({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 126,
            height: 126,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child:
                      Icon(Icons.cloud_outlined, color: c.primary, size: 56),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(Icons.sync, color: c.primary, size: 32),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ConvCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF34C759),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Last synced 2 min ago',
                    style: AppTypography.geist(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                    ),
                  ),
                ),
                Text('3.0 KB', style: AppTypography.eyebrow(color: c.ink3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
