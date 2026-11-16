# Single-grid marking — design

Status: draft, awaiting approval. Date: 2026-11-14.

## Intent

Taking attendance is the core of the app, and it currently offers three
surfaces (Deck, List, Fast) and four fast modes. In real use only one works:
the name grid, swept top to bottom, tapping everyone who is present. The sweep
is what makes it reliable — every name passes under the eye, so nobody is
missed. Search-style modes fail that test (you only mark who you think to look
for) and family marking fails because families rarely attend whole.

Make the grid the only way to mark, fix its one weakness, and delete the rest.

## Goals

- One marking surface: the grid. No surface switch, no per-event mode choice.
- A person can be found in a 50-name grid without reading all 50.
- Nothing is ever hidden from the sweep.
- Editing or removing a person from a session is discoverable.

## Non-goals

- Insights, settings, families, event menu items unrelated to marking.
- The session summary page's layout.

## Anti-goals

- Any filter, search, or ranking that hides names or makes their position
  unpredictable.
- Replacing removed modes with new options or toggles.

## Approaches considered

1. **Letter row that jumps (chosen).** Alphabetical grid; a row of the first
   letters in use; tapping a letter scrolls to that letter's first tile.
   Nothing is hidden, order is predictable, no keyboard.
2. **Letter row that filters.** Same row, but shows only that letter. Rejected:
   hides names, so a sweep done while filtered misses people.
3. **Search field on the grid.** Rejected by the user: marking by search is how
   people get missed, and the keyboard covers half the grid.

## Design

### The grid

- Order: alphabetical by display name (case-insensitive), replacing "most
  frequent first". Guests and visitors on the session sort in with everyone.
- Marked tiles stay in place, filled violet.
- Tile content is the same (given name, surname subtitle), but the given
  name is the clear headline: larger and heavier than today, in full-strength
  ink in both themes (no coloured initial). The given name is never
  truncated: it scales down to fit the tile, and wraps to a second line if
  it still does not fit at the minimum size. Only the surname may ellipsize.
  The surname stays small and quiet. A marked tile keeps exactly the same
  text (name and surname) and is distinguished only by its violet fill — no
  "Here" label or check icon. Screen readers still announce the state
  (selected / present) through semantics.
  The "% recently" rate no longer drives anything on this surface.
- Caption becomes "`N` left" (drop "most frequent first").
- Letter strip down the right edge of the grid (Niagara-launcher style): only
  letters that at least one name starts with, top to bottom, sized to fit the
  grid's height so the strip itself never scrolls. Touching or dragging along
  it scrubs: the grid jumps so that letter's first tile is at the top, and a
  large letter bubble shows mid-screen while the finger is down. It is a
  jump, never a filter.
- The left edge gutter (the grid's side padding, no visible strip) accepts
  the same drag, so either thumb works. It must not overlap tiles or steal
  ordinary grid scrolling, and must not trigger the system back gesture
  (vertical drags only).
- While the grid is scrolled normally, the strip highlights the letter
  currently at the top.
- Accessibility: the strip is one adjustable control (slider semantics,
  value = current letter) rather than 26 sub-48dp buttons.
- "Add someone" pill and its add flow are unchanged.

```
 12 left
 ┌────────┐ ┌────────┐ ┌────────┐ J
 │ Kai    │ │ Karen  │ │ Kevin ✓│ K
 │ Wong   │ │ Garrido│ │ Garrido│ L
 └────────┘ └────────┘ └────────┘ M
                 ( + Add someone )
```

### The session page

- The Deck / List / Fast segmented switch is removed; the page body is always
  the grid. Header tally, Cancel, and the finish control stay.
- A new session always starts with nobody marked. Start modes are removed
  (user decision: all-present is very rare and the smart default is not
  accurate): `AttendanceStartMode`, `Event.defaultAttendanceStartMode`, the
  Attendance Mode picker and its event-menu / event-editor entries, the
  per-member `defaultStatus` field and its editor control, and the
  preseeding code. Stored values are ignored on read; no migration.
- Reopening a past session from history opens the same grid with its
  recorded people shown as marked. The List's confirm mode (Confirm / Reset
  buttons, baseline tracking) goes away with the List.
- In-session "Mark everyone" and "Mark family all present" go away with the
  List and Deck. (The summary page keeps its own.)

### Editing and removing a person

Today this exists only on the session summary page, as an undiscoverable swipe
on each row. Replace the swipe there with a visible per-row "more" control that
opens Edit name / Remove. No edit affordance is added to the grid.

### Removed

- Deck: swipe cards, deck body/footer, hint zones, deck undo.
- In-session List and its grouping preset (picker, `Event.rosterGrouping`).
  `AttendanceRosterList` itself stays — the summary page uses it.
- Fast modes: rapid entry, households, initials pad; `MarkingMode`,
  `Event.markingMode`, the Fast Marking Mode picker, its event-menu and
  event-editor entries.
- Likelihood ranking, where nothing else reads it (Insights has its own
  maths; verify before deleting from `ActiveRosterIndex`).
- Dead `attendance_flow_page.dart`.

### Stored data

`markingMode` and `rosterGrouping` stop being read or written, in both the
local event JSON and the shared-event payload. Old values in existing files
and Drive backups are ignored on read. No migration.

## Constraints

- Fluid Humanist design system, no 1px borders, WCAG AA, 48dp targets.
- Tests updated with the code; coverage stays above 95%. Tests for deleted
  widgets are deleted, not skipped.
- `flutter analyze` clean; full suite runs in CI.

## Delivery order (one PR each)

1. Grid: alphabetical order + letter jump row. Additive.
2. Session page: grid only; remove the switch, Deck, in-session List.
3. Delete the three fast modes, pickers, and the two Event fields.
4. Summary page: visible Edit / Remove in place of the swipe.

## Left to the builder

- How the jump computes its scroll offset (grid row maths vs. keyed tiles).
- Whether to rename `AttendanceDeckPage` / `LikelyHereView` once the Deck and
  ranking are gone (do it as a final mechanical commit if at all).
- Exact letter-row styling within the design system.

## Calls made by Claude, not yet confirmed by the user

- Jump instead of filter for the letter row.
- Edit / Remove fixed on the summary page rather than added to the grid.
