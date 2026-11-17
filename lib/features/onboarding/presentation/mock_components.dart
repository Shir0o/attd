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

/// Cascading member rows: given name over the surname that tells namesakes
/// apart.
class OnboardingMembersArt extends StatelessWidget {
  const OnboardingMembersArt({super.key});

  static const _members = [
    (given: 'Alice', surname: 'Smith'),
    (given: 'Alice', surname: 'Wong'),
    (given: 'Dan', surname: 'Rivera'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return SizedBox(
      width: 290,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _members.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Transform.translate(
              offset: Offset(i * 6.0, 0),
              child: ConvCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    ConvAvatar(letter: _members[i].given[0], size: 36),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _members[i].given,
                          style: AppTypography.fraunces(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _members[i].surname.toUpperCase(),
                          style: AppTypography.eyebrow(
                            color: c.ink2,
                            fontSize: 10,
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
