import 'package:flutter/material.dart';

import '../../../core/design/app_radii.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';

/// Modal bottom sheet for the "Mark everyone" bulk action.
///
/// Returns `true` for "All present", `false` for "All absent", or `null` if
/// the user dismissed / cancelled. Per design at
/// `/tmp/design/attd/project/screens.jsx` (MarkEveryoneSheet, lines 249–296).
class MarkEveryoneSheet {
  MarkEveryoneSheet._();

  static Future<bool?> show(
    BuildContext context, {
    required int memberCount,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => const _Sheet(),
      routeSettings: RouteSettings(
        arguments: {'memberCount': memberCount},
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet();

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final args =
        (ModalRoute.of(context)?.settings.arguments as Map?) ?? const {};
    final memberCount = (args['memberCount'] as int?) ?? 0;
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
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BulkBtn(
                    key: const Key('markEveryoneAbsent'),
                    label: 'All absent',
                    icon: Icons.close_rounded,
                    tone: ConvTone.absent,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
              ],
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
