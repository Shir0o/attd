# Design System: Convocation

The Attendance Tracker uses **Convocation**, an editorial design language that pairs serif display typography with a clinical sans-serif body, postcard-style stamps, and tabular numerals for a calm, considered aesthetic.

This page is a developer reference for design tokens, components, and patterns. **For complete design specifications**, see `DESIGN_SPEC.md` in the repository root.

## Color Palette

All colors are defined in `lib/core/design/app_colors.dart` and exposed via the `ConvocationColors` theme extension.

### Brand Colors

| Token | Light | Dark | Use |
|---|---|---|---|
| `primary` | `#6750A5` | `#B5A4D8` | Buttons, "TODAY" pill, active states, FAB |
| `present` | `#6750A5` | `#C2B5DA` | Present attendance (avatars, stamps, numerals) |
| `absent` | `#E5754D` (coral) | `#EAA585` | Absent attendance (avatars, stamps, numerals) |
| `clayDeep` | `#B47744` | `#DBA572` | Review / medium-confidence cues |

### Surface Ladder

Hierarchy via **tonal shifts** (no hairline borders):

| Token | Purpose | Light | Dark |
|---|---|---|---|
| `bg` | Page background | `#FFFBFE` | `#1F1A1E` |
| `bg2` | Section background | `#F5EFF7` | `#251F2A` |
| `bg3` | Tertiary section | `#F1EBF3` | `#2B2530` |
| `card` | Card surface (rounded 24px) | `#FFFBFE` | `#3B3540` |
| `cardSoft` | Soft card (rounded 22px) | `#FAF1FB` | `#2B2530` |

**Usage Pattern**:

```
Page body (bg)
├── Section 1 (bg2)
├── Section 2 (bg3)
├── Card (card)
│   ├── Row 1
│   └── Row 2
└── Soft Card (cardSoft)
```

Hairlines (1px dividers) **only** for narrow separators inside cards (e.g., present/absent vertical divider in session summary).

### Ink Ladder

Text hierarchy via ink opacity:

| Token | Purpose | Opacity |
|---|---|---|
| `ink` | Primary text (headlines, labels) | 100% |
| `ink2` | Body text (paragraphs, descriptions) | 87% |
| `ink3` | Caption / eyebrow labels | 60% |
| `ink4` | Faint / decorative | 38% |

---

## Typography

Two-font pairing defined in `lib/core/design/app_typography.dart`:

| Style | Font | Size (px) | Weight | Purpose | Usage |
|---|---|---|---|---|---|
| `displayLarge` | Fraunces | 56 | Medium | Onboarding welcomes | "What are we tracking?" |
| `displayMedium` | Fraunces | 44 | Medium | Family edit, member counts | "17 people", "The Smiths" |
| `displaySmall` | Fraunces | 36 | Medium | Page titles | Event title, "Mark attendance" |
| `headlineMedium` | Fraunces | 26 | Medium | Section headings | Family card name (large) |
| `headlineSmall` | Fraunces | 22 | Medium | Card titles, event rows | Event row in hub, family sidebar |
| `bodyMedium` | Geist | 15 | Regular | Body text | Session details, member list |
| `bodySmall` | Geist | 13 | Regular | Secondary body | Timestamps, stats |
| `labelSmall` | Geist | 11 | Semibold | Eyebrow + all-caps captions | "SAVED · 2 hours ago", section labels |

### Editorial Numerals

For large count displays (present/absent, "0 events"):

```dart
Text(
  '17',
  style: AppTypography.displayNumber(
    fontSize: 96,
    color: Theme.of(context).extension<ConvocationColors>()!.present,
  ),
)
```

### Text Styles in Use

- **Headlines**: `displaySmall` or `headlineMedium` (serif)
- **Body**: `bodyMedium` (sans)
- **Section labels**: `labelSmall` (all-caps sans)
- **Timestamps**: `bodySmall` (sans)
- **Counts**: `displayNumber` (serif, large)

---

## Components

All custom widgets live in `lib/core/design/widgets/`. Use these instead of generic Flutter widgets for design consistency.

### ConvCard & ConvCardSoft

Rounded container surfaces (24px / 22px border radius).

```dart
ConvCard(
  child: Column(children: [...]),
)

ConvCardSoft(
  child: Row(children: [...]),
)
```

**Difference**:
- `ConvCard`: Higher contrast (uses `card` surface)
- `ConvCardSoft`: Lower contrast (uses `cardSoft` surface)

### ConvAvatar

Letter avatar with semantic tone.

```dart
ConvAvatar(
  letter: 'J',  // First letter
  tone: ConvAvatarTone.present,  // present, absent, neutral
)
```

**Tones**:
- `present` — Green/tinted with present color
- `absent` — Red/tinted with absent color
- `neutral` — Gray

### ConvStamp

Rotated postcard-style stamp (PRESENT or ABSENT).

```dart
ConvStamp(
  label: 'PRESENT',
  tone: ConvStampTone.present,  // or absent
  rotation: 12,  // Degrees
)
```

**Use Cases**:
- Session summary: display status
- Attendance deck: confirmation stamp
- Status badges

### ConvSegmented

Two-button segmented control with capsule active state.

```dart
ConvSegmented(
  selected: 0,  // 0 or 1
  labels: ['Deck', 'List'],
  onChanged: (index) => setState(() => selected = index),
)
```

### ConvToggle

56×32 present/absent inline toggle.

```dart
ConvToggle(
  value: isPresent,  // true = present, false = absent
  onChanged: (newValue) => setState(() => isPresent = newValue),
)
```

### ConvDayChip

Day-of-week indicator circle (S/M/T/W/T/F/S).

```dart
ConvDayChip(
  day: 'M',
  isActive: true,  // Highlight
  onPressed: () => selectDay('M'),
)
```

### ConvStatChip

Present/Absent/Total stat tile with editorial numeral.

```dart
ConvStatChip(
  label: 'Present',
  count: 12,
  tone: ConvStatChipTone.present,  // present, absent, neutral
)
```

### ConvSectionLabel

Eyebrow row with leading 3×12 bar in semantic tone.

```dart
ConvSectionLabel(
  label: 'THIS WEEK',
  tone: ConvSectionLabelTone.neutral,  // or present, absent
)
```

### ConvFab

60×60 squircle FAB with primary glow.

```dart
FloatingActionButton(
  onPressed: () => addEvent(),
  child: ConvFab(icon: Icons.add),
)
```

### ConvPill & ConvPill.on

Capsule chip with optional leading icon.

```dart
ConvPill(
  label: 'TODAY',
  backgroundColor: primary,
  textColor: Colors.white,
)

ConvPill.on(
  label: 'Marked',
  icon: Icons.check,
  backgroundColor: presentColor,
)
```

---

## Visual Patterns

### No-Line Rule

Hierarchy is defined by **background tonal shifts**, not 1px borders.

**❌ Wrong**:
```dart
Container(
  border: Border(bottom: BorderSide(width: 1, color: hairlineColor)),
  child: [...],
)
```

**✅ Correct**:
```dart
Container(
  color: bg2,  // Shift to next surface tone
  child: [...],
)
```

### Pill Shapes

All buttons and interactive tracks are **pill-shaped** (BorderRadius.circular(999)).

**Button example**:
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(999),
    ),
  ),
  child: Text('Save'),
)
```

### Skeleton Loaders

Every page must show a skeleton while loading data. **Minimum duration: 800ms** to prevent flickering.

```dart
if (snapshot.connectionState == ConnectionState.waiting) {
  return _buildSkeleton();  // Show placeholder with shimmer
}
```

Then after 800ms delay:

```dart
return Future.delayed(Duration(milliseconds: 800))
  .then((_) => _buildContent(snapshot.data));
```

**Shimmer effect** — Use `Shimmer.fromColors` from `shimmer` package to animate placeholder.

### Instant Transitions

Global `NoTransitionsBuilder` removes page transition animations for a fast, app-like feel.

```dart
// In main.dart, theme setup:
pageTransitionsTheme: PageTransitionsTheme(
  builders: {
    TargetPlatform.android: NoTransitionsBuilder(),
    TargetPlatform.iOS: NoTransitionsBuilder(),
  },
),
```

No manual `Navigator.of(context).push()` calls; use named routes with `MaterialApp.onGenerateRoute`.

### Tonal Depth

Hierarchy is built via luminance (darkness) shifts:

1. Page background: `bg` (lightest)
2. Sections: `bg2` → `bg3` (progressively darker)
3. Cards: `card` or `cardSoft`
4. Shadows: subtle, 8dp elevation for floating items

**Correct use**:

```
Page (bg)
├── Hero card (card) — slightly raised
├── Section title (bg2)
├── List rows (bg3)
└── Floating button (card + 16dp shadow)
```

---

## Theme Configuration

**File**: `lib/core/design/app_theme.dart`

Theme setup combines Material design tokens with Convocation extensions:

```dart
class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(primary: kPrimary, ...),
      extensions: [ConvocationColors.light(), ...],
      typography: AppTypography.typography(),
      // Custom component shapes
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(primary: kPrimaryDark, ...),
      extensions: [ConvocationColors.dark(), ...],
      typography: AppTypography.typography(),
    );
  }
}
```

**Access in widgets**:

```dart
// Get colors
final colors = Theme.of(context).extension<ConvocationColors>()!;
Text('Present', style: TextStyle(color: colors.present));

// Get typography
Text('Headline', style: Theme.of(context).textTheme.displaySmall);
```

---

## Color Usage by Feature

### Attendance (Marking)

- **Present**: Primary color (`present` token)
- **Absent**: Absent color (`absent` token)
- **Stamps**: ConvStamp with tone
- **Avatars**: ConvAvatar with tone

### Hub (Dashboard)

- **Event cards**: `card` surface
- **TODAY pill**: Primary color
- **Hero stats**: Editorial numerals in present/absent colors
- **Event rows**: `cardSoft` surface

### Session Summary

- **Hero stats**: Present/Absent numerals
- **Divider**: Hair-thin line between columns
- **Stamps**: PRESENT/ABSENT stamps with tone
- **Links**: Primary color for Regulars/Trends taps

### Insights (Regulars & Trends)

- **Regulars bar**: Present color
- **Trends bar chart**: Present color for bars, dashed gray for average line
- **Session rows**: `cardSoft` surface

### Settings

- **Sign-in hero**: Primary color card with icon
- **Sync button**: Primary
- **Data inspector**: Filter chips in primary, status badges (hidden = gray, orphan = absent)

---

## Dark Mode

Light and dark variants are defined for all tokens:

```dart
class ConvocationColors extends ThemeExtension<ConvocationColors> {
  final Color primary;
  final Color present;
  final Color absent;
  final Color bg;
  // ... etc

  ConvocationColors.light()
    : primary = Color(0xFF6750A5),
      present = Color(0xFF6750A5),
      absent = Color(0xFFE5754D),
      bg = Color(0xFFFFFBFE),
      // ... etc;

  ConvocationColors.dark()
    : primary = Color(0xFFB5A4D8),
      present = Color(0xFFC2B5DA),
      absent = Color(0xFFEAA585),
      bg = Color(0xFF1F1A1E),
      // ... etc;
}
```

**Implementation**: Most Material components (Button, Card, Text) automatically use light/dark variants. Custom components should check `Theme.of(context).brightness`.

---

## Best Practices

1. **Use Design Tokens**: Never hardcode colors; always use `ConvocationColors` or Material tokens
2. **Use Components**: Prefer `ConvCard` over generic `Container`; `ConvAvatar` over custom Text
3. **Maintain Hierarchy**: Use tonal shifts, not lines
4. **Pill Shapes**: All buttons are pill-shaped
5. **Responsive**: Ensure components work on phone (375px) and tablet (1024px)
6. **Test on Both Themes**: Check light AND dark mode
7. **Skeleton Loaders**: Every page must show skeleton for ≥800ms during load
8. **Instant Navigation**: No page transitions; use named routes

---

## Related Files

- `lib/core/design/app_colors.dart` — Color definitions
- `lib/core/design/app_typography.dart` — Font scale and styles
- `lib/core/design/app_theme.dart` — Theme builder
- `lib/core/design/widgets/` — Reusable Convocation components
- `DESIGN_SPEC.md` (repo root) — Complete specification with prototypes

---

**Related pages:**
- [Architecture Overview](/openwiki/architecture.md) — Design system integration in UI architecture
- [Features & Workflows](/openwiki/features.md) — How design system is used in each feature
