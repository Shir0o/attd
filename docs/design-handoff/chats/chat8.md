# Promo Screenshots Redesign

_Started 2026-05-25 16:47 UTC_

---

## User

let's restore the promo 3 trends from archive (but maybe give it another background color so that it's good with the rest of the promotional screenshots. And let's fill in the gap of the streaks (let's not call it streaks or use the words faithful five) for the consistent members (80% from past 8 sessions). and the report for an event (again, not the word streak, so also throughout the whole app)
let's also remove the words "Roll call" throughout the app and play store promotional screenshots

## Assistant

_[tool: list_files]_

_[tool: read_file]_

_[tool: read_file]_

_[tool: grep]_

_[tool: read_file]_

_[tool: read_file]_

_[tool: grep]_

_[tool: str_replace_edit]_

Got it. Let me plan the edits:

1. **Restore Promo 3 (Trends)** — bring it back to the live section with a forest-dark background (not violet-dark like Promo 6). Update the inner "STREAK" chip to neutral language tied to the consistent-members concept ("Regulars · 80% in last 8").
2. **Remove streak vocabulary** — replace the current Promo 3 Streaks/Faithful Five frame entirely.
3. **Remove "Roll call"** from app screens, swipe deck, hub mini, hero promo, cover/type cards, and archive labels.

Let me make the edits:

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: grep]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: grep]_

All references cleaned up. Let me verify the file loads cleanly.

_[tool: done]_

_[tool: fork_verifier_agent]_

Done. Summary of changes:

- **Promo 3 restored** — the Trends/sparkline screenshot is back in the live Play Store row (slot 3), now on a forest-dark background (`oklch(26% 0.05 165)`) so it sits cleanly next to the violet and clay tones instead of doubling up on Promo 6's aubergine.
- **No more "streak"/"faithful five"** — the report's stat chip now reads `REGULARS · 80% IN LAST 8` with the consistent members listed. Same neutral vocabulary used everywhere. SummaryScreen already used "Consistent · 8 wk" — left alone since it fits.
- **No more "Roll call"** — Hub headers, Hub Empty, SwipeDeckB header + completion screen, Promo 1 hero, HubMini in Promo 6, Cover + Type cards, and the archive labels all swapped to "Today" / "Attendance, by hand." / "All marked." / "Postcard". The old Streaks Promo 3 (and its `Promo3Archive` shim) is fully removed.
- **CLAUDE.md** updated to match the renamed archive entry.

## User

sorry I meant don't replace the promo 3 (with the view of most consistent attendees) but restore it as additional

## Assistant

_[tool: read_file]_

_[tool: grep]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

_[tool: str_replace_edit]_

Got it — I'll bring the consistent-attendees screen back as Promo 3 (renamed everywhere to avoid "streak"/"faithful five"), and keep the Trends one as a new Promo 7.

_[tool: done]_

_[tool: fork_verifier_agent]_

Done — both promos are now in the lineup:

- **Promo 3 · Regulars** — sage/green background (`oklch(93% 0.04 155)`), shows the consistent-members view. Eyebrow "REGULARS", title "The reliable few", sub "Members at 80%+ across the last 8 sessions". Hero row shows Alice at 8/8 with an 8-segment session ribbon; ranked list below shows each member's session-by-session hit pattern.
- **Promo 7 · Trends** — kept the forest-dark restored panel with the sparkline and "Regulars · 80% in last 8" chip.

No "streak", "faithful five", or "roll call" anywhere in the app or marketing.

## User

Verifier agent check completed

## Assistant

All set — verifier confirmed both promos render correctly and the language sweep is clean.

