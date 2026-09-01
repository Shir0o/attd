/// Which **fast marking surface** an event's attendance session offers
/// alongside the Deck and the List.
///
/// This is a **per-event preset** (chosen in the event editor), not a live
/// in-session toggle — the picked mode fills a third segment beside Deck and
/// List. Unlike [RosterGrouping] there is no one-time picker sheet: an event
/// that has never had one chosen resolves to [kDefaultMarkingMode] silently,
/// so starting a session never gains an extra prompt.
enum MarkingMode {
  /// No fast surface — the session offers only the Deck and the List.
  none,

  /// Bottom-anchored search that keeps focus and clears itself after each mark.
  rapidEntry,

  /// Tap-to-mark grid ordered by recent attendance.
  likelyHere,

  /// Search returns households; one tap marks a whole family.
  households,

  /// Two-stage initials filter that replaces the system keyboard.
  initialsPad,
}

/// Applied to every event whose preset has never been chosen.
const MarkingMode kDefaultMarkingMode = MarkingMode.likelyHere;

extension MarkingModeLabel on MarkingMode {
  /// Full name, as shown in the event editor's dropdown.
  String get label => switch (this) {
        MarkingMode.none => 'Off',
        MarkingMode.rapidEntry => 'Rapid entry',
        MarkingMode.likelyHere => 'Likely here',
        MarkingMode.households => 'Households',
        MarkingMode.initialsPad => 'Initials pad',
      };

  /// Short name, as shown on the in-session segment.
  String get shortLabel => switch (this) {
        MarkingMode.none => 'Off',
        MarkingMode.rapidEntry => 'Rapid',
        MarkingMode.likelyHere => 'Likely',
        MarkingMode.households => 'Family',
        MarkingMode.initialsPad => 'Initials',
      };

  /// One-line "best when", shown under the dropdown value.
  String get hint => switch (this) {
        MarkingMode.none =>
          'Only the Deck and the List. Best for a short roster.',
        MarkingMode.rapidEntry =>
          'Type a few letters and tap. The field keeps focus and clears itself.',
        MarkingMode.likelyHere =>
          'Tap names from a grid ordered by who usually turns up.',
        MarkingMode.households =>
          'Search finds families. One tap marks the whole household.',
        MarkingMode.initialsPad =>
          'Filter by initials with no keyboard — good one-handed.',
      };
}
