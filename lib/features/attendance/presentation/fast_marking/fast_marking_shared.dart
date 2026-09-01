import 'package:flutter/material.dart';

import '../../../../core/design/app_radii.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/conv_widgets.dart';
import '../../models/member.dart';

/// A mark the user just made, kept so it can be undone in one tap.
typedef MarkedEntry = ({Member member, bool previousPresent});

/// Records a completed mark on the undo stack, keeping the most recent
/// [limit].
///
/// Marks in *both* directions go on: an accidental un-mark is exactly the slip
/// worth being able to take back.
void pushMark(
  List<MarkedEntry> stack,
  Member member,
  bool previousPresent, {
  int limit = 3,
}) {
  stack.insert(0, (member: member, previousPresent: previousPresent));
  if (stack.length > limit) stack.removeLast();
}

/// Shared row for the fast marking surfaces: avatar, name, one-line context,
/// and a trailing state control. Tapping anywhere on the row toggles.
class FastMarkingRow extends StatelessWidget {
  const FastMarkingRow({
    super.key,
    required this.member,
    required this.isPresent,
    required this.subtitle,
    required this.onTap,
    this.isTopHit = false,
    this.query = '',
  });

  final Member member;
  final bool isPresent;
  final String subtitle;
  final VoidCallback onTap;

  /// The search text this row matched, highlighted inside the name so it is
  /// obvious why the row is in the results.
  final String query;

  /// The row the keyboard's return key would mark — drawn with a ring.
  final bool isTopHit;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final bg = isTopHit
        ? Color.alphaBlend(c.primary.withValues(alpha: 0.08), c.card)
        : isPresent
            ? Color.alphaBlend(c.present.withValues(alpha: 0.06), c.card)
            : c.card;

    return Material(
      color: bg,
      borderRadius: AppRadii.compactR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.compactR,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadii.compactR,
            border: Border.all(
              color: isTopHit ? c.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ConvAvatar(
                letter: member.displayName.isNotEmpty
                    ? member.displayName[0].toUpperCase()
                    : '?',
                tone: isPresent ? ConvTone.present : ConvTone.neutral,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HighlightedName(
                      name: member.displayName,
                      query: query,
                      color: c.ink,
                      highlight: Color.alphaBlend(
                        c.primary.withValues(alpha: 0.22),
                        c.card,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPresent ? 'Already here' : subtitle,
                      style: AppTypography.geist(
                        fontSize: 12,
                        color: isPresent ? c.present : c.ink3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _MarkDot(isPresent: isPresent),
            ],
          ),
        ),
      ),
    );
  }
}

/// The member's name with the matched run of [query] tinted. Falls back to
/// plain text when there is no query or it does not appear.
class _HighlightedName extends StatelessWidget {
  const _HighlightedName({
    required this.name,
    required this.query,
    required this.color,
    required this.highlight,
  });

  final String name;
  final String query;
  final Color color;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.geist(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: color,
    );
    final q = query.trim().toLowerCase();
    final at = q.isEmpty ? -1 : name.toLowerCase().indexOf(q);
    if (at < 0) {
      return Text(
        name,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: name.substring(0, at)),
          TextSpan(
            text: name.substring(at, at + q.length),
            style: TextStyle(backgroundColor: highlight),
          ),
          TextSpan(text: name.substring(at + q.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _MarkDot extends StatelessWidget {
  const _MarkDot({required this.isPresent});

  final bool isPresent;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isPresent ? c.present : Colors.transparent,
        border: Border.all(
          color: isPresent ? c.present : c.ink4,
          width: 1.5,
        ),
      ),
      child: Icon(
        Icons.check_rounded,
        size: 18,
        color: isPresent ? c.onPrimary : c.primary,
      ),
    );
  }
}

/// The last few marks, most recent first, each undoable in one tap.
class JustMarkedStack extends StatelessWidget {
  const JustMarkedStack({
    super.key,
    required this.entries,
    required this.onUndo,
  });

  final List<MarkedEntry> entries;
  final ValueChanged<MarkedEntry> onUndo;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final c = context.conv;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 2),
          child: Text(
            'LAST FEW MARKS · TAP TO UNDO',
            style: AppTypography.eyebrow(color: c.ink4),
          ),
        ),
        for (var i = 0; i < entries.length; i++)
          Opacity(
            opacity: i == 0 ? 0.85 : 0.5,
            child: InkWell(
              key: Key('fastMarkingUndo_${entries[i].member.id}'),
              borderRadius: AppRadii.compactR,
              onTap: () => onUndo(entries[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    ConvAvatar(
                      letter: entries[i].member.displayName.isNotEmpty
                          ? entries[i].member.displayName[0].toUpperCase()
                          : '?',
                      tone: entries[i].previousPresent
                          ? ConvTone.absent
                          : ConvTone.present,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entries[i].member.displayName,
                        style: AppTypography.geist(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: c.ink2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.undo_rounded, size: 14, color: c.ink3),
                    const SizedBox(width: 5),
                    Text(
                      'Undo',
                      style: AppTypography.geist(fontSize: 12, color: c.ink3),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The bottom-anchored search field the rapid-entry and households surfaces
/// share. It sits directly on top of the keyboard rather than behind it, and
/// the caller re-focuses it after every mark.
class MarkingSearchField extends StatelessWidget {
  const MarkingSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.hintText,
    this.caption,
    this.trailingLabel,
    this.onSubmitted,
    this.fieldKey,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hintText;
  final String? caption;
  final String? trailingLabel;
  final VoidCallback? onSubmitted;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: c.cardSoft,
              borderRadius: AppRadii.compactR,
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 10),
                  child: Icon(Icons.search_rounded, color: c.ink3, size: 20),
                ),
                Expanded(
                  child: TextField(
                    key: fieldKey,
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onChanged: onChanged,
                    onSubmitted: (_) => onSubmitted?.call(),
                    style: AppTypography.geist(fontSize: 15, color: c.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      hintText: hintText,
                      hintStyle:
                          AppTypography.geist(fontSize: 15, color: c.ink3),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                if (trailingLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      trailingLabel!,
                      style: AppTypography.geist(fontSize: 11.5, color: c.ink3),
                    ),
                  ),
                if (controller.text.isNotEmpty)
                  IconButton(
                    key: const Key('fastMarkingClear'),
                    icon: Icon(Icons.clear_rounded, color: c.ink3, size: 18),
                    onPressed: onClear,
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
              child: Text(
                caption!,
                style: AppTypography.geist(fontSize: 11.5, color: c.ink3),
              ),
            ),
        ],
      ),
    );
  }
}

/// Offered when a query matches nobody — records the typed name as a walk-in
/// without leaving the marking flow.
class AddGuestRow extends StatelessWidget {
  const AddGuestRow({super.key, required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return InkWell(
      key: const Key('fastMarkingAddGuest'),
      onTap: onTap,
      borderRadius: AppRadii.compactR,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: AppRadii.compactR,
          border: Border.all(color: c.hair, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.person_add_alt_1_outlined, size: 20, color: c.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nobody matches "$query" — add as a guest',
                style: AppTypography.geist(fontSize: 14, color: c.ink2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One-line context under a name: the household, plus how often the person has
/// turned up lately when there is enough history for it to mean anything.
String memberSubtitle(String? familyName, double? rate) {
  final household =
      (familyName == null || familyName.trim().isEmpty) ? 'Loner' : familyName;
  if (rate == null) return household;
  return '$household · ${(rate * 100).round()}% recently';
}
