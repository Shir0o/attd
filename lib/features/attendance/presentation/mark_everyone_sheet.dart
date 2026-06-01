import 'package:flutter/material.dart';

import '../../../core/design/app_radii.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';

/// The bulk default the user picked in [MarkEveryoneSheet].
///
/// - [present] / [absent] apply a single status to everyone.
/// - [smart] resolves each member from recent attendance history (present if
///   here ≥80% of the last 8 sessions, absent if ≤20%, otherwise left as-is).
enum BulkMarkChoice { present, absent, smart }

/// Modal bottom sheet for the "Mark everyone" bulk action.
///
/// Returns a [BulkMarkChoice], or `null` if the user dismissed / cancelled.
/// Per the "02 Quick Marking" design — the bulk sheet offers
/// All present / All absent / Smart defaults.
class MarkEveryoneSheet {
  MarkEveryoneSheet._();

  static Future<BulkMarkChoice?> show(
    BuildContext context, {
    required int memberCount,
  }) {
    return showModalBottomSheet<BulkMarkChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _Sheet(memberCount: memberCount),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.memberCount});

  final int memberCount;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final noun = memberCount == 1 ? 'member' : 'members';

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: AppRadii.sheetR,
      ),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: c.ink4.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Bulk attendance',
              style: AppTypography.fraunces(
                fontSize: 24,
                fontWeight: FontWeight.w400,
                color: c.ink,
                letterSpacing: -0.48,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Apply a status to all $memberCount $noun. '
              'You can change any of them after.',
              style: AppTypography.geist(
                fontSize: 14,
                color: c.ink2,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _BulkBtn(
                    key: const Key('markEveryonePresent'),
                    label: 'All present',
                    icon: Icons.check_rounded,
                    tone: ConvTone.present,
                    onTap: () =>
                        Navigator.of(context).pop(BulkMarkChoice.present),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BulkBtn(
                    key: const Key('markEveryoneAbsent'),
                    label: 'All absent',
                    icon: Icons.close_rounded,
                    tone: ConvTone.absent,
                    onTap: () =>
                        Navigator.of(context).pop(BulkMarkChoice.absent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SmartBtn(
              key: const Key('markEveryoneSmart'),
              onTap: () => Navigator.of(context).pop(BulkMarkChoice.smart),
            ),
            const SizedBox(height: 16),
            Material(
              color: c.cardSoft,
              borderRadius: AppRadii.tileR,
              child: InkWell(
                key: const Key('markEveryoneCancel'),
                borderRadius: AppRadii.tileR,
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: AppTypography.geist(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: c.ink,
                      ),
                    ),
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

class _BulkBtn extends StatelessWidget {
  const _BulkBtn({
    super.key,
    required this.label,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final ConvTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final fg = switch (tone) {
      ConvTone.present => c.present,
      ConvTone.absent => c.absent,
      ConvTone.neutral => c.ink,
    };
    final bg = Color.alphaBlend(fg.withValues(alpha: 0.12), c.card);
    final iconBg = Color.alphaBlend(fg.withValues(alpha: 0.18), c.card);

    return Material(
      color: bg,
      borderRadius: AppRadii.tileR,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.geist(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width "Smart defaults" tile. Resolves each member from recent
/// attendance history instead of applying a single status to everyone.
class _SmartBtn extends StatelessWidget {
  const _SmartBtn({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;

    return Material(
      color: c.cardSoft,
      borderRadius: AppRadii.tileR,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    c.primary.withValues(alpha: 0.16),
                    c.card,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome, size: 22, color: c.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart defaults',
                      style: AppTypography.geist(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Present if here ≥80% of the last 8 sessions',
                      style: AppTypography.geist(
                        fontSize: 12.5,
                        color: c.ink3,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
