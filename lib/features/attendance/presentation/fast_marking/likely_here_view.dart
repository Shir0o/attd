import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radii.dart';
import '../../../../core/design/app_shadows.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/conv_widgets.dart';
import '../../domain/active_roster_index.dart';
import '../../models/member.dart';
import 'fast_marking_model.dart';

/// Fast marking without typing: the roster as a grid of tappable names, A to Z,
/// swept top to bottom. Marked names stay in place and fill violet, so nobody
/// moves under the thumb and the order is always predictable.
///
/// A letter strip down the right edge (and the same drag in the left gutter)
/// jumps the grid to a letter; it never filters, so every name stays in the
/// sweep. The one extra action is a floating "Add someone" pill for a person
/// who is not on the grid at all.
class LikelyHereView extends StatefulWidget {
  const LikelyHereView({
    super.key,
    required this.roster,
    required this.onToggle,
    required this.onAddGuest,
    this.addSomeoneKey,
    this.disableAnimations = false,
  });

  final FastMarkingRoster roster;
  final MemberMarkCallback onToggle;
  final VoidCallback onAddGuest;

  /// Lets the add sheet grow out of the "Add someone" pill (#222 M1); pass the
  /// same key to `showConvMorphSheet`. Also measured by [snackBarMarginAbove].
  final GlobalKey<ConvMorphSourceState>? addSomeoneKey;
  final bool disableAnimations;

  /// The global rect of [memberId]'s tile in a [LikelyHereView] somewhere
  /// under [context], when that tile lies fully inside the grid's viewport.
  /// Null when there is no such tile, or it is scrolled partly or wholly out
  /// of view (#222 M3 lands on it only when it is on screen).
  ///
  /// Call it outside build, e.g. from a ticker or a post-frame callback.
  static Rect? visibleTileRect(BuildContext context, String memberId) {
    final key = _chipKey(memberId);
    Element? tile;
    void find(Element element) {
      if (tile != null) return;
      if (element.widget.key == key) {
        tile = element;
        return;
      }
      element.visitChildElements(find);
    }

    context.visitChildElements(find);
    final box = tile?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport is! RenderBox) return null;
    final viewportBox = viewport as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final view = viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
    const slop = 0.5;
    final fullyVisible = rect.left >= view.left - slop &&
        rect.top >= view.top - slop &&
        rect.right <= view.right + slop &&
        rect.bottom <= view.bottom + slop;
    return fullyVisible ? rect : null;
  }

  static Key _chipKey(String memberId) => Key('likelyHereChip_$memberId');

  /// How far the floating Add someone pill sits above the view's bottom edge.
  static const double addSomeoneInset = 24;

  /// Margin for a floating SnackBar over this view that parks it just above
  /// the Add someone pill instead of covering it, so the next add needn't wait
  /// for the snackbar to time out. Measured, so it holds at large text sizes.
  /// Null (the theme's inset) when the pill isn't on screen.
  static EdgeInsets? snackBarMarginAbove(GlobalKey addSomeoneKey) {
    final pill = addSomeoneKey.currentContext?.size;
    if (pill == null) return null;
    // Sides and top match the Material default inset.
    return EdgeInsets.fromLTRB(15, 5, 15, addSomeoneInset + pill.height + 8);
  }

  @override
  State<LikelyHereView> createState() => _LikelyHereViewState();
}

/// The grid's fixed geometry; the letter jump is plain row maths on it.
const int _columns = 3;
const double _tileExtent = 64;
const double _tileSpacing = 8;
const double _rowExtent = _tileExtent + _tileSpacing;

/// The left side padding, which doubles as an invisible scrub gutter.
const double _gutterWidth = 16;

/// The letter strip's width, which is also the grid's right side padding.
const double _stripWidth = 32;

/// The letter a name files under in the strip: its first character,
/// upper-cased.
String _letterOf(Member member) {
  final name = member.displayName.trim();
  if (name.isEmpty) return '#';
  return String.fromCharCode(name.runes.first).toUpperCase();
}

class _LikelyHereViewState extends State<LikelyHereView> {
  final _scroll = ScrollController();

  /// Strip letters in grid order → index of that letter's first tile.
  Map<String, int> _firstIndex = const {};

  /// The letter the strip highlights: the one at the top of the grid, or the
  /// one last jumped to.
  String? _current;

  /// The letter under the finger while scrubbing; shows the big bubble.
  String? _scrubbing;

  /// Set while the view moves the grid itself, so the jump target is not
  /// overwritten by whichever letter happens to start the top row.
  bool _jumping = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_followScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<Member> get _ordered => widget.roster.alphabetical;

  Future<void> _toggle(Member member) async {
    await widget.onToggle(member, !widget.roster.isPresent(member));
    unawaited(HapticFeedback.selectionClick());
  }

  void _followScroll() {
    if (_jumping || _scrubbing != null || _ordered.isEmpty) return;
    // The first row whose tile (not just its spacing) is still on screen.
    final row = ((_scroll.offset + _tileSpacing) / _rowExtent).floor();
    final i = (row * _columns).clamp(0, _ordered.length - 1);
    final letter = _letterOf(_ordered[i]);
    if (letter != _current) setState(() => _current = letter);
  }

  /// Scrolls so [letter]'s first tile sits at the top of the grid (or as near
  /// as the end of the list allows). Never filters.
  void _jumpTo(String letter) {
    final first = _firstIndex[letter];
    if (first == null) return;
    if (_scroll.hasClients) {
      final position = _scroll.position;
      final target = ((first ~/ _columns) * _rowExtent)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      _jumping = true;
      _scroll.jumpTo(target);
      _jumping = false;
    }
    setState(() => _current = letter);
  }

  /// Scrubs to the strip letter at height [dy] of a strip [height] tall. The
  /// gutter spans the same height as the strip, so both share this maths.
  void _scrubAt(double dy, double height) {
    final letters = _firstIndex.keys.toList(growable: false);
    if (letters.isEmpty) return;
    final letter = letters[_StripLayout(height, letters.length).indexAt(dy)];
    if (letter == _scrubbing) return;
    _scrubbing = letter;
    unawaited(HapticFeedback.selectionClick());
    _jumpTo(letter);
  }

  void _endScrub() {
    if (_scrubbing == null) return;
    setState(() => _scrubbing = null);
  }

  void _step(int delta) {
    final letters = _firstIndex.keys.toList(growable: false);
    final at = letters.indexOf(_current ?? letters.first);
    final next = at + delta;
    if (next < 0 || next >= letters.length) return;
    _jumpTo(letters[next]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final roster = widget.roster;

    // Stable A to Z order; marking never shuffles it.
    final ordered = _ordered;
    final firstIndex = <String, int>{};
    for (var i = 0; i < ordered.length; i++) {
      firstIndex.putIfAbsent(_letterOf(ordered[i]), () => i);
    }
    _firstIndex = firstIndex;
    final current = firstIndex.containsKey(_current)
        ? _current
        : firstIndex.keys.firstOrNull;
    final scrubbing = _scrubbing;

    return Stack(
      children: [
        Positioned.fill(
          child: ordered.isEmpty
              ? Center(
                  child: Text(
                    'Nobody on this roster yet.',
                    style: AppTypography.geist(fontSize: 14, color: c.ink3),
                  ),
                )
              : GridView.builder(
                  controller: _scroll,
                  // The side paddings are the scrub gutter (left) and
                  // the letter strip (right), so neither covers a tile.
                  // Bottom padding clears the floating pill so the last
                  // row can scroll out from under it.
                  padding: const EdgeInsets.fromLTRB(
                    _gutterWidth,
                    0,
                    _stripWidth,
                    96,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _columns,
                    mainAxisExtent: _tileExtent,
                    crossAxisSpacing: _tileSpacing,
                    mainAxisSpacing: _tileSpacing,
                  ),
                  itemCount: ordered.length,
                  itemBuilder: (context, i) => _LikelyChip(
                    key: LikelyHereView._chipKey(ordered[i].id),
                    member: ordered[i],
                    index: roster.index,
                    isPresent: roster.isPresent(ordered[i]),
                    onTap: () => _toggle(ordered[i]),
                    disableAnimations: widget.disableAnimations,
                  ),
                ),
        ),
        if (firstIndex.isNotEmpty) ...[
          // Left gutter: the same scrub as the strip, invisible.
          // Vertical drags only, so horizontal edge swipes (system
          // back) pass through, and taps on it do nothing.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _gutterWidth,
            child: LayoutBuilder(
              builder: (context, box) => GestureDetector(
                key: const Key('likelyHereLetterGutter'),
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onVerticalDragStart: (d) =>
                    _scrubAt(d.localPosition.dy, box.maxHeight),
                onVerticalDragUpdate: (d) =>
                    _scrubAt(d.localPosition.dy, box.maxHeight),
                onVerticalDragEnd: (_) => _endScrub(),
                onVerticalDragCancel: _endScrub,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: _stripWidth,
            child: _LetterStrip(
              letters: firstIndex.keys.toList(growable: false),
              current: current!,
              onScrub: _scrubAt,
              onEnd: _endScrub,
              onStep: _step,
            ),
          ),
        ],
        Positioned(
          // Beside the strip, not on it.
          right: firstIndex.isEmpty ? 16 : _stripWidth + 4,
          bottom: LikelyHereView.addSomeoneInset,
          child: _AddSomeonePill(
            sourceKey: widget.addSomeoneKey,
            onTap: widget.onAddGuest,
            disableAnimations: widget.disableAnimations,
          ),
        ),
        if (scrubbing != null)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Center(child: _LetterBubble(letter: scrubbing)),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddSomeonePill extends StatelessWidget {
  const _AddSomeonePill({
    required this.sourceKey,
    required this.onTap,
    required this.disableAnimations,
  });

  final GlobalKey<ConvMorphSourceState>? sourceKey;
  final VoidCallback onTap;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return ConvMorphSource(
      key: sourceKey,
      color: c.primary,
      label: const _AddSomeoneLabel(),
      child: ConvPressable.builder(
        disableAnimations: disableAnimations,
        builder: (context, pressed) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: AppShadows.fab(c.primary, pressed: pressed),
          ),
          child: Material(
            color: c.primary,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              key: const Key('likelyHereAddGuest'),
              borderRadius: BorderRadius.circular(999),
              onTap: onTap,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                child: _AddSomeoneLabel(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddSomeoneLabel extends StatelessWidget {
  const _AddSomeoneLabel();

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.person_add_alt_1_outlined,
          color: c.onPrimary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          'Add someone',
          style: AppTypography.geist(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: c.onPrimary,
          ),
        ),
      ],
    );
  }
}

class _LikelyChip extends StatelessWidget {
  const _LikelyChip({
    super.key,
    required this.member,
    required this.index,
    required this.isPresent,
    required this.onTap,
    required this.disableAnimations,
  });

  final Member member;
  final ActiveRosterIndex index;
  final bool isPresent;
  final VoidCallback onTap;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final hasDistinctSurname = index.hasDistinctSurname(member);

    // A marked tile keeps exactly the same text; only the violet fill
    // changes. The selected state is announced through semantics instead.
    return Semantics(
      container: true,
      button: true,
      selected: isPresent,
      label: member.displayName,
      onTap: onTap,
      excludeSemantics: true,
      // Pops on press (#222 M4); the tap, and so the present fill, lands on
      // release at the bottom of the press.
      child: ConvPressable(
        preset: ConvPressPreset.pop,
        disableAnimations: disableAnimations,
        child: Material(
          color: isPresent ? c.present : c.card,
          borderRadius: AppRadii.compactR,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadii.compactR,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: AppRadii.compactR,
                border: Border.all(color: isPresent ? c.present : c.hair),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Flexible: the name gets whatever height the surname
                  // leaves, and shrinks into it rather than truncating.
                  Flexible(
                    child: _GivenName(
                      index.displayNameFor(member),
                      color: isPresent ? c.onPrimary : c.ink,
                    ),
                  ),
                  if (hasDistinctSurname) ...[
                    const SizedBox(height: 2),
                    Text(
                      index.surnameFor(member).toUpperCase(),
                      // ink2, not ink3/ink4: small text on the dark card
                      // needs it for WCAG AA.
                      style: AppTypography.eyebrow(
                        color: isPresent ? c.onPrimary : c.ink2,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tile's headline: the given name, never truncated. It shows at full size
/// when it fits, scales down on one line while that stays at or above
/// [minSize], and otherwise wraps at [minSize] (shrinking further only if the
/// wrapped lines are taller than the tile allows).
class _GivenName extends StatelessWidget {
  const _GivenName(this.text, {required this.color});

  final String text;
  final Color color;

  static const double maxSize = 16;
  static const double minSize = 12;

  TextStyle _style(double size) => AppTypography.geist(
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: color,
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: _style(maxSize)),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final fitsOneLine = painter.width * minSize / maxSize <= box.maxWidth;
        painter.dispose();

        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: fitsOneLine
              ? Text(
                  text,
                  style: _style(maxSize),
                  maxLines: 1,
                  softWrap: false,
                )
              : SizedBox(
                  width: box.maxWidth,
                  child: Text(text, style: _style(minSize), softWrap: true),
                ),
        );
      },
    );
  }
}

/// Where the strip's letters sit: equal cells, at most [maxCell] tall, centred
/// in a strip [height] tall, so the strip always fits and never scrolls.
class _StripLayout {
  _StripLayout(this.height, this.count)
      : cell = count == 0 ? 0 : math.min(maxCell, height / count);

  static const double maxCell = 22;

  final double height;
  final int count;
  final double cell;

  double get top => (height - cell * count) / 2;

  /// The letter at [dy]; above or below the letters clamps to the ends.
  int indexAt(double dy) =>
      ((dy - top) / cell).floor().clamp(0, count - 1).toInt();
}

/// The right-edge letter strip (Niagara-style). Touching or dragging along it
/// scrubs the grid; to a screen reader it is one adjustable control rather
/// than a column of tiny buttons.
class _LetterStrip extends StatelessWidget {
  const _LetterStrip({
    required this.letters,
    required this.current,
    required this.onScrub,
    required this.onEnd,
    required this.onStep,
  });

  final List<String> letters;
  final String current;
  final void Function(double dy, double height) onScrub;
  final VoidCallback onEnd;
  final void Function(int delta) onStep;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final at = letters.indexOf(current);
    final hasNext = at < letters.length - 1;
    final hasPrevious = at > 0;

    return Semantics(
      key: const Key('likelyHereLetterStrip'),
      container: true,
      slider: true,
      label: 'Jump to letter',
      value: current,
      increasedValue: hasNext ? letters[at + 1] : null,
      decreasedValue: hasPrevious ? letters[at - 1] : null,
      onIncrease: hasNext ? () => onStep(1) : null,
      onDecrease: hasPrevious ? () => onStep(-1) : null,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) {
            final layout = _StripLayout(box.maxHeight, letters.length);
            // Raw pointer events, not a drag recogniser: the jump lands on
            // touch-down, with no slop to cross first.
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => onScrub(e.localPosition.dy, box.maxHeight),
              onPointerMove: (e) => onScrub(e.localPosition.dy, box.maxHeight),
              onPointerUp: (_) => onEnd(),
              onPointerCancel: (_) => onEnd(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final letter in letters)
                    SizedBox(
                      key: Key('likelyHereLetter_$letter'),
                      width: _stripWidth,
                      height: layout.cell,
                      child: Center(
                        child: _StripLetter(
                          letter,
                          size: layout.cell,
                          selected: letter == current,
                          color: c,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StripLetter extends StatelessWidget {
  const _StripLetter(
    this.letter, {
    required this.size,
    required this.selected,
    required this.color,
  });

  final String letter;
  final double size;
  final bool selected;
  final ConvocationColors color;

  @override
  Widget build(BuildContext context) {
    final c = color;
    final glyph = math.min(size, 20.0);
    return Container(
      width: glyph,
      height: glyph,
      alignment: Alignment.center,
      // A tonal violet dot for the current letter; no outline.
      decoration: selected
          ? BoxDecoration(color: c.primary, shape: BoxShape.circle)
          : null,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          letter,
          style: AppTypography.geist(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: selected ? c.onPrimary : c.ink3,
          ),
        ),
      ),
    );
  }
}

/// The large letter shown mid-grid while a finger is on the strip or gutter.
class _LetterBubble extends StatelessWidget {
  const _LetterBubble({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    return Container(
      key: const Key('likelyHereLetterBubble'),
      width: 88,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.primary,
        shape: BoxShape.circle,
        boxShadow: AppShadows.fab(c.primary),
      ),
      child: Text(
        letter,
        style: AppTypography.displayNumber(fontSize: 48, color: c.onPrimary),
      ),
    );
  }
}
