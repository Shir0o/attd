import 'package:flutter/material.dart';

import '../../../core/design/app_radii.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_primitives.dart';
import '../../../core/design/widgets/conv_theme.dart';

// ─────────────────────────────────────────────────────────────
// Onboarding editorial art widgets (mirror screens.jsx 545–709)
// ─────────────────────────────────────────────────────────────

/// Static mock of the real marking grid: name tiles sorted A to Z, a few
/// filled violet as present, and the slim letter strip down the right edge.
/// Decorative only, so it is excluded from semantics.
class OnboardingGridArt extends StatelessWidget {
  const OnboardingGridArt({super.key});

  static const _members = [
    (given: 'Alma', surname: 'Reyes'),
    (given: 'Ben', surname: 'Okafor'),
    (given: 'Cara', surname: 'Lindqvist'),
    (given: 'Dev', surname: 'Patel'),
    (given: 'Elena', surname: 'Voss'),
    (given: 'Finn', surname: 'Hale'),
    (given: 'Gia', surname: 'Moretti'),
    (given: 'Hugo', surname: 'Brandt'),
    (given: 'Iris', surname: 'Tanaka'),
  ];
  static const _present = {1, 4, 6};
  static const _letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I'];
  static const _columns = 3;
  static const _tileHeight = 56.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return ExcludeSemantics(
      child: SizedBox(
        width: 290,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var r = 0; r < _members.length ~/ _columns; r++) ...[
                    if (r > 0) const SizedBox(height: _gap),
                    Row(
                      children: [
                        for (var k = 0; k < _columns; k++) ...[
                          if (k > 0) const SizedBox(width: _gap),
                          Expanded(
                            child: _GridTile(
                              given: _members[r * _columns + k].given,
                              surname: _members[r * _columns + k].surname,
                              isPresent: _present.contains(r * _columns + k),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 18,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final letter in _letters)
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: letter == _letters.first
                          ? BoxDecoration(
                              color: c.primary,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Text(
                        letter,
                        style: AppTypography.geist(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color:
                              letter == _letters.first ? c.onPrimary : c.ink3,
                        ),
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

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.given,
    required this.surname,
    required this.isPresent,
  });

  final String given;
  final String surname;
  final bool isPresent;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Container(
      height: OnboardingGridArt._tileHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isPresent ? c.present : c.card,
        borderRadius: AppRadii.compactR,
      ),
      // FittedBox keeps the text inside the tile under large text scales.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              given,
              style: AppTypography.geist(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.15,
                color: isPresent ? c.onPrimary : c.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              surname.toUpperCase(),
              style: AppTypography.eyebrow(
                color: isPresent ? c.onPrimary : c.ink2,
                fontSize: 9,
              ),
            ),
          ],
        ),
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
