import 'package:flutter/widgets.dart';

import '../app_motion.dart';

/// Swaps a page's loading [skeleton] for its [child] with a 200 ms crossfade
/// (#222 M7). It replaces the `loading ? skeleton : content` choice; the
/// page's own minimum skeleton time (AGENTS.md, 800 ms) is decided by the
/// caller and unchanged.
///
/// While fading, the skeleton and the content are both in the tree. When
/// [motionEnabled] is false it snaps like the plain conditional it replaces.
class SkeletonSwitcher extends StatelessWidget {
  const SkeletonSwitcher({
    super.key,
    required this.loading,
    required this.skeleton,
    required this.child,
    this.disableAnimations = false,
  });

  final bool loading;
  final Widget skeleton;
  final Widget child;

  /// The host widget's test/override flag; see [motionEnabled].
  final bool disableAnimations;

  static const Duration duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    if (!motionEnabled(context, disableAnimations: disableAnimations)) {
      return loading ? skeleton : child;
    }
    return AnimatedSwitcher(
      duration: duration,
      // Both layers take the full space the page gives them, top-aligned,
      // instead of the default centring.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        fit: StackFit.passthrough,
        children: [...previous, if (current != null) current],
      ),
      child: KeyedSubtree(
        key: ValueKey<bool>(loading),
        child: loading ? skeleton : child,
      ),
    );
  }
}
