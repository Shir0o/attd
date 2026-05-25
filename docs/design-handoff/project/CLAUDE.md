# Attendance Tracker — Convocation Redesign

## Handoff notes for Claude Code

The design file is `Attendance Redesign.html` (rendered from `main.jsx` +
`screens.jsx` + `swipe.jsx` + `parts.jsx` + `marketing.jsx`).

### What to ship

For the **Quick Marking** flow (section `02 · Quick Marking`), ship **Deck A**
only — that's the `<SwipeDeckA>` component in `swipe.jsx`. Both Day and Night
themes are designed.

### What NOT to ship — archived directions

There is a section labelled **`✕ Archive · DO NOT BUILD`** at the bottom of
the canvas. Everything inside it is an explored-and-rejected direction kept
for reference only. **Do not implement, port, or rebuild any of it.**

Currently archived:

- **`SwipeDeckB` — "Postcard"**
  Rejected: postcard framing feels heavy and ceremonial; competes with the
  swipe gesture.
- **`SwipeDeckC` — "Ribbon carousel"**
  Rejected: horizontal ribbon obscures the next card and slows down marking.

These components still exist in `swipe.jsx` so the archive section renders,
but they should not be wired into the production app. If you're cleaning up,
you can delete `SwipeDeckB` and `SwipeDeckC` along with this archive section
once the redesign is shipped.

### Machine-readable signal

Archived artboards are wrapped in `<ArchivedWrap>` (see `main.jsx`), which
stamps each card with a visible "ARCHIVED · DO NOT BUILD" badge and sets:

```html
<div data-archived="true"
     data-do-not-implement="true"
     data-handoff-note="ARCHIVED — rejected design direction. ...">
```

If you're scripting against the design file, filter on
`[data-archived="true"]` to skip these.
