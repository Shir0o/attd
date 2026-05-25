# Vendored handoff bundle

This directory is a snapshot of the Claude Design handoff bundle for the
Convocation overhaul. The original lived at `/tmp/design/attd/` (ephemeral);
this committed copy is the durable reference.

## What's tracked

The textual design source — the irreplaceable spec:

- `README.md` — the original handoff agent's instructions
- `chats/` — the conversation transcripts that explain the intent behind each
  design decision
- `project/*.jsx`, `project/*.html`, `project/*.css`, `project/*.md` — the
  prototype source: `screens.jsx`, `parts.jsx`, `swipe.jsx`, `marketing.jsx`,
  `app.css`, etc.

## What's NOT tracked

Reference PNG renders are gitignored to keep the repo small:

- `project/uploads/` — ~9.8 MB of reference screenshots
- `project/screenshots/` — ~40 KB of canvas overview renders

If you need them, re-fetch the original handoff URL via WebFetch and extract
into this directory; the gitignore will keep them local-only. The JSX
prototypes are the source-of-truth — the PNGs are just renders of them.
