import 'package:flutter/material.dart';

import '../../../core/design/app_radii.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';

/// Minimum time a handoff page shows its skeleton (AGENTS.md).
const Duration handoffSkeletonMinimum = Duration(milliseconds: 800);

/// Loading state shared by the handoff pages: the shape of the loaded page.
class HandoffSkeleton extends StatelessWidget {
  const HandoffSkeleton({super.key, this.disableAnimations = false});

  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => AppShimmer(
          width: w,
          height: h,
          borderRadius: BorderRadius.circular(6),
          disableAnimations: disableAnimations,
        );
    return Padding(
      key: const Key('handoffSkeleton'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(90, 12),
          const SizedBox(height: 14),
          bar(240, 30),
          const SizedBox(height: 10),
          bar(160, 14),
          const SizedBox(height: 28),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: AppShimmer(
                    width: double.infinity,
                    height: 72,
                    borderRadius: AppRadii.compactR,
                    disableAnimations: disableAnimations,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 28),
          AppShimmer(
            width: double.infinity,
            height: 52,
            borderRadius: BorderRadius.circular(26),
            disableAnimations: disableAnimations,
          ),
        ],
      ),
    );
  }
}

/// Present / Absent / Guests tiles.
class HandoffStatRow extends StatelessWidget {
  const HandoffStatRow({
    super.key,
    required this.present,
    required this.absent,
    required this.guests,
  });

  final int present;
  final int absent;
  final int guests;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ConvStatChip(
            label: 'Present',
            value: '$present',
            tone: ConvTone.present,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ConvStatChip(
            label: 'Absent',
            value: '$absent',
            tone: ConvTone.absent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ConvStatChip(
            label: 'Guests',
            value: '$guests',
            tone: ConvTone.neutral,
          ),
        ),
      ],
    );
  }
}

/// A calm message card for a refused file or a finished import.
class HandoffMessage extends StatelessWidget {
  const HandoffMessage({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.info_outline,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: c.ink2, size: 28),
        const SizedBox(height: 12),
        Text(
          title,
          style: AppTypography.fraunces(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: AppTypography.geist(fontSize: 15, color: c.ink2, height: 1.45),
        ),
      ],
    );
  }
}
