# UI/UX bloat reduction — decision log

Design-only review, 2026-11-14. No code changed. Goal: keep only the features
the app cannot succeed without. Each item is settled with the owner before
moving on.

## Settled

### 1. Marking surfaces
One surface: the name grid. See
[single-grid marking design](2026-11-14-single-grid-marking-design.md).

- Kept: grid, sorted by first name, swept top to bottom; side letter strip
  that jumps (never filters); "Add someone".
- Cut: Deck, in-session List, Rapid entry, Households, Initials pad, the
  Deck/List/Fast switch, Fast Marking Mode picker, likelihood ranking,
  "Here" label on marked tiles.
- Why: only the full sweep is reliable; search and family marking miss
  people; ranking was not accurate.

### 2. Attendance Mode
- Cut: all three start modes, per-member default status, in-session
  "Mark everyone". A session always starts with nobody marked.
- Why: never used; all-present is very rare; the smart default is not
  accurate.

### 3. Event menu and editor
- Menu goes from eight actions to three: Edit, Hand off, History.
- Cut from menu: Attendance Mode, Fast Marking Mode, View Insights (the rate
  strip on the card already opens it).
- Moved into Edit Event: Manage Members (the editor's Roster field) and
  Delete (the editor's own button).
- Editor loses "Group roster by" and "Fast marking mode"; keeps Name, Time,
  Frequency, Date / repeat days, Roster.
- Event card unchanged.

### 4. Share Event
Replaced by a one-shot handoff file. See
[event handoff design](2026-11-14-event-handoff-design.md). Documented only;
to be validated in real use if and when it is built.

### 5. Session summary page
- Kept: roster list with search, tap to flip present/absent, Add attendee,
  Delete session.
- Late toggle: first kept, then cut on 2026-11-15 once Insights (its only
  display) was removed.
- Changed: Edit name / Remove move from a hidden swipe to a visible per-row
  menu.
- Cut: status/family grouping toggle (always by status), "Mark everyone",
  the "View data policy" info icon.
- Deferred: "Sync to CISA" button, decided with CISA in item 9.

### 6. Insights
Removed entirely and replaced by "Who to check on". See
[who-to-check-on design](2026-11-15-who-to-check-on-design.md).

- Why: the owner never opens Insights; the need is who is flagged for
  attention.
- Five fixed rules, hub card + report, no settings. The canvas's Alert rules
  editor and "When to tell me" scheduling are cut.
- Export moves to the History page.

### 7. Families
- Cut the whole feature (list, details, suggest, assign solo members,
  resolve duplicates) and the "Manage Families" settings row.
- Why: its two uses, family marking and grouping the list by family, are
  already cut. The surname under each name disambiguates.
- Stored family data is left in place and ignored. Backup, the storage
  inspector, onboarding mock-ups, and the event editor reference families
  and need updating when this is built.

### 8. Backup and sync
- Kept: Google Drive sign-in and backup, Sync Now, version history, Google
  Sheets sync (owner needs it), Backup to Local Storage.
- Cut: the Background Auto-Sync toggle (always on when signed in) and the
  Require Wi-Fi toggle.
- Moved behind developer options: Manage Backup Data (storage inspector).

### 9. Rest of Settings
- Kept: Theme, App Lock, crash diagnostics opt-in, Privacy Policy,
  Feedback, About.
- **Manage Members (all members): kept.** It is the app-wide member list,
  distinct from an event's roster. Merging duplicate members moves here as
  an action; today it lives only inside Manage Backup Data, which is going
  behind developer options.
- **Reminders: kept.** The owner sometimes forgets to take attendance. The
  existing behaviour is the requirement: a local notification after the
  session's scheduled start, suppressed once attendance is recorded.
  Simplified to one on/off switch; the offset selector is cut and fixed at
  one hour after start (Claude's call).
- **CISA Campus Tracker: kept but hidden** behind the existing developer
  unlock (tap the version number), including the "Sync to CISA" button on
  the session summary. The general public never sees it.
- Reports: cut the "Enable Report Export" toggle and Advanced Reporting;
  one "Export CSV" on the History page.

### 10. First-timers
- "Add someone" adds to the roster by default, so a newcomer has a history
  and "Newcomer follow-up" / "One-time visitor" can flag them. Marking a
  one-off guest stays available as the secondary choice; guest marks are
  never flagged.

## Review complete

Every area has been reviewed. Remaining work is implementation, per the
linked designs.

## Found along the way

- `lib/features/attendance/presentation/attendance_flow_page.dart` is dead
  code (318 lines, referenced nowhere).
