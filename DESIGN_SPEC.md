# Design System Specification: Convocation

## 1. Creative North Star

Convocation is an editorial take on attendance. Where the prior "Fluid Humanist" system was warm and tonal, Convocation pairs a serif display voice with a clinical sans body, then adds postcard-style stamps, segmented controls, and big tabular numerals. The goal is an interface that feels like a beautifully printed weekly bulletin — calm, considered, and human.

The source-of-truth prototype is the handoff bundle vendored at [`docs/design-handoff/`](docs/design-handoff/) (see `project/Attendance Redesign.html` for the entry point and `project/screens.jsx` / `project/parts.jsx` / `project/marketing.jsx` for component-level detail).

## 2. Color tokens

All values are sRGB approximations of the OKLCH tokens in `attd/project/app.css`. The Flutter source of truth is [`lib/core/design/app_colors.dart`](lib/core/design/app_colors.dart) plus the `ConvocationColors` `ThemeExtension`, surfaced via `Theme.of(context).extension<ConvocationColors>()!`.

### Brand
| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `primary` | `#6750A5` | `#B5A4D8` | Buttons, "TODAY" pill, day-chip active, FAB |
| `present` | `= primary` | `#C2B5DA` | Present semantic — avatars, stamp, summary numerals |
| `absent` | `#E5754D` (coral) | `#EAA585` | Absent semantic — stamp, avatar, summary numerals |
| `clayDeep` | `#B47744` | `#DBA572` | Review / medium-confidence cues |

### Surface ladder
`bg` → `bg2` → `bg3` → `card` → `cardSoft`. Use shifts in tone — never hairline borders — to delimit sections. Hairlines (`hair`) are only for narrow dividers inside cards (e.g. the present/absent vertical rule on the Session Summary hero).

### Ink ladder
`ink` (primary text), `ink2` (body), `ink3` (captions / eyebrow), `ink4` (faint / decorative).

## 3. Typography

Two-font pairing wired up in [`app_typography.dart`](lib/core/design/app_typography.dart):

* **Fraunces** (display + headline). Optical-size 72/144. Used for display numerals, screen titles, family/member headlines.
* **Geist** (body + label + title). Used everywhere else.

Key scale:

| Style | Family | Size | Purpose |
| --- | --- | --- | --- |
| `displayLarge` | Fraunces | 56 | Onboarding welcomes |
| `displayMedium` | Fraunces | 44 | Family edit name, Members "17 people" |
| `displaySmall` | Fraunces | 36 | "What are we tracking?" |
| `headlineMedium` | Fraunces | 26 | "Mark attendance", Family card name |
| `headlineSmall` | Fraunces | 22 | Family card name (compact), event title in rows |
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

## 5. Elevation

Most surfaces are flat — depth comes from tonal layering (e.g. `card` on `bg2`). Soft tinted shadows live in `app_shadows.dart` and are reserved for:

* The editorial Hub "Up Next" card.
* Onboarding postcards.
* The FAB (uses `AppShadows.fab(primary)` glow).

## 6. Motion

* Toggle thumb slides 200 ms with `cubic-bezier(0.2, 0.7, 0.3, 1)`.
* Page transitions are intentionally **off** (we keep `NoTransitionsBuilder`). The editorial layout reads better when screens snap.
* Swipe-deck stamps fade in proportional to drag distance and rotate per `swipe.jsx`.

## 7. Two screens unique to Convocation

These don't exist in the prototype HTML — they're invented from Play-Store promo frames in `attd/project/marketing.jsx`:

* **Consistent members** — members at ≥80% across the last 8 sessions. Hero gradient card + ranked list with 8-segment attendance ribbons. Reachable from Session Summary.
* **Trends** — 12-week sparkline of present-rate, present/absent split with trend arrow, regulars strip. Reachable from Session Summary.

Both rely on data already available from `SessionRepository` and `AttendanceRepository`; no schema changes.
