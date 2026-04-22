---
layout: default
title: Design System Specification
---

# 🎨 Design System Specification: The Fluid Humanist

## 1. Overview & Creative North Star
**Creative North Star: "The Welcoming Curator"**
This design system moves beyond the rigid, utilitarian nature of typical attendance software. Instead of a cold, administrative tool, we are building a "Digital Concierge"—an experience that feels as fluid and effortless as a physical swipe.

To achieve this, we reject the "spreadsheet" aesthetic. We embrace **intentional asymmetry**, where large, expressive illustrations break the container bounds, and **tonal depth**, where hierarchy is defined by soft shifts in color rather than harsh lines. The goal is an interface that breathes, prioritizing high-end editorial layouts that guide the user through onboarding with warmth and absolute clarity.

---

## 2. Colors & Surface Architecture
The palette is rooted in a sophisticated violet and soft lily-white base, designed to reduce cognitive load and eye strain.

### The "No-Line" Rule
**Explicit Instruction:** Traditional 1px solid borders are strictly prohibited for sectioning or containment.
* **The Technique:** Define boundaries through background shifts. For example, a `surface-container-low` (#f9f1fb) card should sit on a `surface` (#fef7ff) background.
* **Tonal Transitions:** Use the contrast between `surface-container` tiers to create "islands of information" that feel integrated, not boxed in.

### Surface Hierarchy & Nesting
Treat the UI as a physical stack of fine, semi-transparent paper.
* **Level 0 (Base):** `background` (#fef7ff)
* **Level 1 (Sections):** `surface-container-low` (#f9f1fb)
* **Level 2 (Active Cards):** `surface-container-lowest` (#ffffff)
* **Level 3 (Floating Elements):** Use **Glassmorphism**. Floating modals or menus should use `surface` at 80% opacity with a `24px` backdrop blur to allow the brand colors to bleed through softly.

### Signature Textures
Main CTAs and Hero onboarding sections should utilize a **Linear Gradient** (135°) transitioning from `primary` (#6750a5) to `primary-container` (#cab6ff). This adds a "soul" and professional luster that flat hex codes cannot replicate.

---

## 3. Typography: The Editorial Scale
We use **IBM Plex Sans** (interpreted through the Plus Jakarta and Be Vietnam scales for weight/feel) to balance technical precision with human warmth.

* **Display (Large/Medium):** `3.5rem` / `2.75rem`. Use for high-impact onboarding welcomes. Tracking should be tightened (-2%) to create a "compact-premium" feel.
* **Headline (Small/Medium):** `1.5rem` / `1.75rem`. Use these to ask direct questions (e.g., "Ready to swipe in?").
* **Body (Large/Medium):** `1rem` / `0.875rem`. Set with generous line-height (1.6) to ensure the "Soft Humanist" aesthetic is maintained.
* **Labels:** `0.75rem`. Use `on-surface-variant` (#625d68) to keep these secondary but legible.

**Hierarchy Note:** Always pair a `display-lg` headline with a `body-lg` subtext. The extreme contrast in scale creates a high-end, editorial look that screams "intentional design."

---

## 4. Elevation & Depth
We eschew the "Material 2" drop-shadow style in favor of **Tonal Layering**.

* **The Layering Principle:** Place a `surface-container-lowest` (#ffffff) card atop a `surface-container-high` (#ede5f2) background. The delta in luminance creates a natural, soft lift.
* **Ambient Shadows:** If a floating action button (FAB) requires a shadow, use a large blur (`32px`) at `4%` opacity. The shadow color must be a tinted `primary-dim` (#5b4497) rather than grey, simulating natural light passing through a violet lens.
* **The "Ghost Border" Fallback:** For accessibility on input fields, use `outline-variant` (#b7afbc) at **20% opacity**. Never use 100% opaque borders.

---

## 5. Components

### Buttons (The Signature Pill)
* **Primary:** Pill-shaped (`rounded-full`), using the Primary-to-Container gradient. Text: `on-primary` (#fdf7ff).
* **Secondary:** Pill-shaped, `surface-container-highest` (#e8dfed) background with `on-surface` (#35313b) text.
* **Interaction:** On hover, increase the `surface-tint` (#6750a5) overlay by 8%.

### Input Fields
* **Structure:** No bottom line. Use a `surface-container-low` (#f9f1fb) filled container with a `rounded-md` (1.5rem) corner radius.
* **State:** On focus, the container shifts to `surface-container-lowest` (#ffffff) with a 2px `primary` ghost-border (20% opacity).

### Cards & Lists
* **Rule:** Divider lines are forbidden.
* **Separation:** Use `spacing-6` (2rem) of vertical white space or a subtle shift from `surface` to `surface-container-low` to separate list items.
* **Illustration Placement:** Cards should often feature "bleeding" illustrations—graphics that extend beyond the card’s top or right boundary to break the grid.

### Progress Indicators (Onboarding)
* Use a sequence of varying-width pills. The active step is a long `primary` pill; inactive steps are small, circular `primary-container` dots.

---

## 6. Do’s and Don’ts

### Do:
* **Do** use asymmetrical layouts. Place a large illustration on the top-right and a display headline on the bottom-left to create visual "rhythm."
* **Do** use `spacing-16` (5.5rem) for hero-section padding. Breathing room is a luxury signal.
* **Do** ensure illustrations use the `secondary` (#4d6645) and `tertiary` (#376b21) palettes to provide a natural, organic contrast to the violet UI.

### Don't:
* **Don't** use pure black (#000000) for text. Use `on-surface` (#35313b) to maintain the soft aesthetic.
* **Don't** use sharp corners. Everything must adhere to the `rounded-md` or `rounded-full` scale.
* **Don't** stack more than three levels of surface containers. Too much nesting leads to visual clutter.

---

## 7. Contextual Component: The "Swipe-Action" Track
Given the "Speed Swipe" context, the core interaction component is a horizontal track.
* **Track:** `surface-container-highest` (#e8dfed), `rounded-full`.
* **Handle:** A `primary` gradient pill with a "chevron-right" icon.
* **Micro-interaction:** As the handle is swiped, the track color should dynamically fill with `primary-fixed` (#cab6ff), creating a tactile sense of progress.
