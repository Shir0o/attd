import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/conv_widgets.dart';
import '../../models/member.dart';
import '../../utils/session_roster_utils.dart';
import 'fast_marking_model.dart';
import 'fast_marking_shared.dart';

/// Fast marking with no keyboard at all: pick a first-name initial, then a
/// surname initial. Two taps typically cut a large roster to a handful, the pad
/// never moves, and nothing is ever occluded — which is what makes this the
/// one-handed option while walking a room.
///
/// Letters with no remaining *unmarked* match are dimmed and inert, so a tap
/// can never land on an empty result set.
class InitialsPadView extends StatefulWidget {
  const InitialsPadView({
    super.key,
    required this.roster,
    required this.onToggle,
    required this.onAddGuest,
  });

  final FastMarkingRoster roster;
  final MemberMarkCallback onToggle;
  final VoidCallback onAddGuest;

  @override
  State<InitialsPadView> createState() => _InitialsPadViewState();
}

class _InitialsPadViewState extends State<InitialsPadView> {
  static const String _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const int _maxResults = 5;
  static const int _maxUndo = 3;

  final List<MarkedEntry> _justMarked = [];
  String? _first;
  String? _last;

  Map<String, Set<String>> get _index => initialsIndex(widget.roster.unmarked);

  /// The letters still worth tapping at the current stage.
  Set<String> get _enabled {
    final index = _index;
    if (_first == null) return index.keys.toSet();
    return index[_first] ?? const {};
  }

  List<Member> get _results {
    if (_first == null) return const [];
    // Unmarked first: a letter only lights up while it still has an unmarked
    // match, so that match must be the one the list actually shows.
    final unmarked = <Member>[];
    final marked = <Member>[];
    for (final m in widget.roster.members) {
      final initials = nameInitials(m.displayName);
      if (initials.first != _first) continue;
      if (_last != null && initials.last != _last) continue;
      (widget.roster.isPresent(m) ? marked : unmarked).add(m);
    }
    final out = [...unmarked, ...marked];
    return out.length > _maxResults ? out.sublist(0, _maxResults) : out;
  }

  void _tapLetter(String letter) {
    setState(() {
      if (_first == null) {
        _first = letter;
        return;
      }
      _last ??= letter;
    });
    unawaited(HapticFeedback.selectionClick());
  }

  void _back() {
    setState(() {
      if (_last != null) {
        _last = null;
      } else {
        _first = null;
      }
    });
  }

  void _reset() => setState(() {
        _first = null;
        _last = null;
      });

  Future<void> _mark(Member member) async {
    final wasPresent = widget.roster.isPresent(member);
    await widget.onToggle(member, !wasPresent);
    if (!mounted) return;
    setState(() {
      pushMark(_justMarked, member, wasPresent, limit: _maxUndo);
      // Marking is the end of one lookup — clear back to the full pad so the
      // next person starts from the same place every time.
      _first = null;
      _last = null;
    });
    unawaited(HapticFeedback.selectionClick());
  }

  Future<void> _undo(MarkedEntry entry) async {
    await widget.onToggle(entry.member, entry.previousPresent);
    if (!mounted) return;
    setState(() => _justMarked.remove(entry));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final results = _results;
    final enabled = _enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                JustMarkedStack(entries: _justMarked, onUndo: _undo),
                if (_justMarked.isNotEmpty) const SizedBox(height: 16),
                if (results.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      '${widget.roster.members.length} → ${results.length}',
                      style: AppTypography.eyebrow(color: c.ink3),
                    ),
                  ),
                  for (final m in results)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FastMarkingRow(
                        key: Key('fastMarkingResult_${m.id}'),
                        member: m,
                        isPresent: widget.roster.isPresent(m),
                        subtitle: widget.roster.subtitleFor(m),
                        onTap: () => _mark(m),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: c.bg2,
            border: Border(top: BorderSide(color: c.hair)),
          ),
          // 12pt gutters, not 16: at 16 the seven keys fall to 43.9pt wide on
          // a 375pt phone, under the 44pt hit-target floor.
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // One Expanded carries the prompt so the chips and the guest
              // affordance always fit: two chips plus the prompt is wider than
              // a phone.
              Row(
                children: [
                  if (_first != null) ...[
                    _InitialChip(
                      chipKey: const Key('initialsChip_first'),
                      label: 'FIRST',
                      letter: _first!,
                      onClear: _reset,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (_last != null) ...[
                    _InitialChip(
                      chipKey: const Key('initialsChip_last'),
                      label: 'SURNAME',
                      letter: _last!,
                      onClear: () => setState(() => _last = null),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      _first == null
                          ? 'Pick a first-name initial'
                          : _last == null
                              ? 'Now a surname initial'
                              : '',
                      style: AppTypography.geist(fontSize: 12, color: c.ink3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConvPill(
                    key: const Key('initialsAddGuest'),
                    label: 'Guest',
                    ghost: true,
                    leading: const Icon(Icons.person_add_alt_1_outlined),
                    onTap: widget.onAddGuest,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // A fixed key height, not an aspect ratio: the keys must stay a
              // thumb-sized 46pt however wide the screen is, or the pad
              // balloons off the bottom of a tablet.
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: 46,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                children: [
                  for (final letter in _letters.split(''))
                    _PadKey(
                      key: Key('initialsKey_$letter'),
                      label: letter,
                      enabled: enabled.contains(letter),
                      onTap: () => _tapLetter(letter),
                    ),
                  _PadKey(
                    key: const Key('initialsKey_back'),
                    icon: Icons.backspace_outlined,
                    enabled: _first != null,
                    onTap: _back,
                  ),
                  _PadKey(
                    key: const Key('initialsKey_reset'),
                    icon: Icons.undo_rounded,
                    enabled: _first != null,
                    onTap: _reset,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InitialChip extends StatelessWidget {
  const _InitialChip({
    required this.chipKey,
    required this.label,
    required this.letter,
    required this.onClear,
  });

  final Key chipKey;
  final String label;
  final String letter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return InkWell(
      key: chipKey,
      onTap: onClear,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
        decoration: BoxDecoration(
          color: c.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.eyebrow(
                color: c.onPrimary.withValues(alpha: 0.75),
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              letter,
              style: AppTypography.geist(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.onPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.close_rounded,
              size: 13,
              color: c.onPrimary.withValues(alpha: 0.75),
            ),
          ],
        ),
      ),
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({
    super.key,
    this.label,
    this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Material(
      color: enabled ? c.card : c.bg3.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: enabled ? c.hair : Colors.transparent),
          ),
          child: icon != null
              ? Icon(icon, size: 18, color: enabled ? c.ink2 : c.ink4)
              : Text(
                  label!,
                  style: AppTypography.geist(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: enabled ? c.ink : c.ink4,
                  ),
                ),
        ),
      ),
    );
  }
}
