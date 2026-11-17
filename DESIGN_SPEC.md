# Design System Specification: Convocation

## 1. Creative North Star

Convocation is an editorial take on attendance. Where the prior "Fluid Humanist" system was warm and tonal, Convocation pairs a serif display voice with a clinical sans body, then adds postcard-style stamps, segmented controls, and big tabular numerals. The goal is an interface that feels like a beautifully printed weekly bulletin — calm, considered, and human.

This document is the durable source of truth for the design system. The original HTML/JSX prototype lives in the Claude Design handoff bundle (`Attendance Redesign.html`, `screens.jsx`, `parts.jsx`, `marketing.jsx`); it is **not vendored** in the repo — re-fetch it fresh from the handoff URL whenever you need prototype-level detail.

## 2. Color tokens

All values are sRGB approximations of the OKLCH tokens in `attd/project/app.css`. The Flutter source of truth is [`lib/core/design/app_colors.dart`](lib/core/design/app_colors.dart) plus the `ConvocationColors` `ThemeExtension`, surfaced via `Theme.of(context).extension<ConvocationColors>()!`.

### Brand
| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `primary` | `#6750A5` | `#B5A4D8` | Buttons, "TODAY" pill, day-chip active, FAB |
| `present` | `= primary` | `#C2B5DA` | Present semantic — avatars, stamp, summary numerals |
| `absent` | `#E5754D` (coral) | `#EAA585` | Absent semantic — stamp, avatar, summary numerals |
| `clayDeep` | `#B47744` | `#DBA572` | Review / medium-confidence cues |
| `danger` | `#BA1A1A` | `#FFB4AB` | Destructive actions (delete) — ≥4.5:1 on the light surface ladder |

### Surface ladder
`bg` → `bg2` → `bg3` → `card` → `cardSoft`. Use shifts in tone — never hairline borders — to delimit sections. Hairlines (`hair`) are only for narrow dividers inside cards (e.g. the rule between paired stat tiles).

### Ink ladder
`ink` (primary text), `ink2` (body), `ink3` (captions / eyebrow), `ink4` (faint / decorative).

## 3. Typography

Two-font pairing wired up in [`app_typography.dart`](lib/core/design/app_typography.dart):

* **Fraunces** (display + headline). Optical-size 72/144. Used for display numerals, screen titles, member headlines.
* **Geist** (body + label + title). Used everywhere else.

Key scale:

| Style | Family | Size | Purpose |
| --- | --- | --- | --- |
| `displayLarge` | Fraunces | 56 | Onboarding welcomes |
| `displayMedium` | Fraunces | 44 | Members "17 people" |
| `displaySmall` | Fraunces | 36 | "What are we tracking?" |
| `headlineMedium` | Fraunces | 26 | "Mark attendance" |
| `headlineSmall` | Fraunces | 22 | Event title in rows |
| `bodyMedium` | Geist | 15 | Default body |
| `labelSmall` | Geist | 11 (uppercase, +14% tracking) | Eyebrow / all-caps captions |

For editorial numerals (Present / Absent counts, "0 events" empty state), use `AppTypography.displayNumber(fontSize: 96, color: …)`.

## 4. Components

The prototype's primitives map to Flutter widgets under `lib/core/design/widgets/`:

* `ConvAvatar` — letter avatar; `tone: present | absent | neutral`.
* `ConvPill` / `ConvPill.on` — capsule chip, optional leading icon.
* `ConvStamp` — rotated postcard stamp (PRESENT / ABSENT).
* `ConvSegmented` — two-button segmented control with capsule active state.
* `ConvToggle` — 56×32 present/absent inline toggle.
* `ConvDayChip` — 28px circle S/M/T/W/T/F/S indicator.
* `ConvStatChip` — Present/Absent/Total tile with editorial numeral.
* `ConvSectionLabel` — eyebrow row with leading 3×12 bar in semantic tone.
* `ConvFab` — 60×60 squircle with primary glow.
* `ConvCard` / `ConvCardSoft` — 24px / 22px radius surfaces.
* `ConvSearchField` — 14px radius (`AppRadii.compactR`) tonal `cardSoft` search bar with leading `Icons.search_rounded`, borderless `TextField` (including on focus, per the no-line rule), conditional clear button (`Icons.clear_rounded`), and optional trailing widget (e.g. inline add button or match counter).

## 5. Elevation

Most surfaces are flat — depth comes from tonal layering (e.g. `card` on `bg2`). Soft tinted shadows live in `app_shadows.dart` and are reserved for:

* The editorial Hub "Up Next" card.
* Onboarding postcards.
* The FAB (uses `AppShadows.fab(primary)` glow).

## 6. Motion

* Toggle thumb slides 200 ms with `cubic-bezier(0.2, 0.7, 0.3, 1)`.
* Page transitions are intentionally **off** (we keep `NoTransitionsBuilder`). The editorial layout reads better when screens snap.
* **Exception: shared-element handoffs.** Pages still snap, but the violet control the user touched may visibly become the next thing on top of the instant change (e.g. the Hub **+** travelling on an arc into the **Create event** pill). See ADR 0008.
* **Morphing sheets.** A filled control (`ConvMorphSource`) can grow into a bottom sheet via `showConvMorphSheet` (`morph`): the sheet starts at the control's rect and radius, the control's colour fades out over ~15–55% while the content fades in from ~30% with a 6 px settle, and the keyboard rises only once the sheet has formed. Cancel (scrim, back) collapses it back into the control (~300 ms); drag-down and submit slide it off the bottom instead. Today only the marking grid's **Add someone** pill uses it; text buttons and icons keep the plain slide-up sheet.
* **Landing flight.** Submitting that sheet flies a violet shuttle (`showConvLandingFlight`, `morph`) on an arc from the control used to where the person landed: their name tile on the grid when it is fully on screen, otherwise the "added · Here" snackbar. Its label fades out over the first ~30% and its corners ease from the stadium to the tile radius. The grid never scrolls to the tile.
* **Tally and progress.** The marking header's counts roll their changed digits like an odometer (`ConvRollingNumber`, `house`; up when the count rises, down when it falls) and the progress fills ease to their new width (`ConvProgressFill`, `house`).
* **Done carries progress** (`DoneProgressPill`). The header's **Done** is a violet pill. While marking, its pale violet wash fills with a violet `ConvProgressFill` at the session progress (replacing the thin bar) and the label turns on-primary where the fill passes under it. At 0 left it is fully violet and one glow ring fades out (~700 ms, decelerate), once per completion. Confirm lists keep their two-tone present/absent bar and a solid violet Done.
* **Skeleton crossfade** (`SkeletonSwitcher`). Every skeleton page crossfades skeleton to content over 200 ms instead of snapping; the 800 ms minimum skeleton time is unchanged. A sliver skeleton (the Hub) fades its loaded list in over the same 200 ms.
* **Segmented thumb.** The selected thumb of `ConvSegmented` (wherever a two-way choice is needed) slides and resizes to the new segment over `house`.
* Motion tokens (`AppMotion`):
  * `morph` — 400 ms, `cubic-bezier(0.05, 0.7, 0.1, 1)` (emphasized decelerate). Container transforms and shared elements.
  * `house` — 220 ms, `cubic-bezier(0.2, 0.7, 0.3, 1)`. In-surface changes: counts, thumbs, tiles, bar heights.
  * `exit` — 200 ms, `cubic-bezier(0.3, 0, 0.8, 0.15)` (emphasized accelerate). Dismissals and collapsing back into the source.
* Violet primary pills and FABs press in (`ConvPressable`, scale 0.97 over ~110 ms while the shadow tightens, spring back over ~260 ms). Mark tiles use the *pop* preset (scale 0.94, spring back over ~320 ms).
* All of the above runs only when `motionEnabled(context, disableAnimations: ...)` is true: it is false when the widget's `disableAnimations` flag is set or the system "Remove animations" setting is on, and then behaviour is exactly as without motion.
* Name tiles on the grid use the *pop* press preset above; the side letter strip jumps the grid to a letter and never filters.

## 7. Who to check on

A hub card and a report list roster members flagged by five fixed rules (Not coming recently, Sudden drop, Gone quiet, Newcomer follow-up, One-time visitor). Each row shows the reason in one line and the last eight meetings as dots. Every figure is derived on read from sessions and the event roster; nothing is persisted.
