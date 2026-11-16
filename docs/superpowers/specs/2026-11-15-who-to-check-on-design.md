# "Who to check on" replaces Insights — design

Status: agreed with the owner 2026-11-15; design only, not built.
Visual source: the "Weekly attendance report" design canvas
(https://claude.ai/artifact/AsnZi89JeRzTUV6fxBxZVA), artboards `Main` and
`Report`. Where this document and the canvas disagree, this document wins
(see "Changes to the canvas").

## Intent

The owner never opens Insights. It answers "how is the event doing"; the
owner needs "who do I need to reach". Replace the whole Insights feature with
a short list of people who need attention, and nothing to configure.

## Goals

- Show who needs attention, why, and let the owner tick them off.
- Two screens, zero settings.
- Flags mean the same thing on every event.

## Non-goals

- Event-level analytics (rate over time, best/lowest, regulars table).
- Per-event or per-user rule tuning.
- Scheduled reports or push notifications.

## Anti-goals

- Any new settings screen, toggle list, or threshold editor.
- A list that never empties.

## Approaches considered

1. **Fixed rules, hub card + report (chosen).** Smallest surface; nothing to
   configure; always current because it is computed when the hub loads.
2. **The canvas as drawn**, with a per-event Alert rules editor (5 switches,
   11 numbers) and "When to tell me" scheduling. Rejected: it rebuilds the
   Insights Customize sheet and adds notification scheduling.
3. **Trim existing Insights to seven fixed sections.** Rejected: still
   answers a question the owner does not ask.

## Design

### Rules (fixed, same for every event)

"Missed" means no present mark. Meetings are counted back from the event's
latest session, not from today.

| Flag | Rule | Tone |
|---|---|---|
| Not coming recently | Came at least 2 times, then missed the last 3 meetings | strong |
| Sudden drop | Came to 75% of the previous 8, then missed 3 of the last 4 | strong |
| Gone quiet | Came 3 or more times, not seen for 6 weeks | soft |
| Newcomer follow-up | Came once, first seen in the last 4 weeks | soft |
| One-time visitor | Came once, not seen for 8 weeks | soft |

These numbers are constants in code. If one proves wrong in real use it is
changed once, for everyone.

When a person matches several rules on one event, show the most serious one
(order as in the table).

### Hub card: "Check on this week"

- Sits above the event list. Up to six people across all events, most
  serious first; each row: name, event, flag, and an eight-dot history (last
  eight meetings, newest on the right: came / missed lately / missed earlier
  / no meeting yet).
- Footer row opens the report. With nobody to check on, the card shows a
  calm empty state rather than disappearing.
- Replaces the attendance-rate strip on the event card and every
  "View Insights" entry.

### Report: "Who to check on"

- One card per person; a line per event they are flagged on: flag, dots, and
  a plain reason ("Missed the last 3 · last here Oct 23").
- Event filter (All / each event) when there is more than one event.
- **Followed up** tick on each card. A ticked person leaves the hub card and
  drops to the bottom of the report, dimmed, until they trigger a *new* flag
  (a different rule, or the same rule after attending again).
- **Stop flagging** action on each card, with undo, for someone who has
  moved on. They are never flagged for that event again unless re-enabled
  from their member page.

### After marking

The session summary shown after Done carries one line when relevant:
"3 people to check on", opening the report. This replaces any notification.

### Removed

- Insights page, all eleven sections, range switch, Customize sheet,
  `InsightsConfig` and its per-event fields, ADR 0007 (superseded).
- The **Late** toggle on the session summary and the late flag's display:
  with Insights gone nothing shows it. Stored late flags are left in place
  and ignored.
- **Export** moves from Insights to the History page.

### Changes to the canvas

- Delete the `Alerts` artboard (rule editor, "Inactive people" list, "When
  to tell me").
- `Report`: remove "Runs every Monday at 8 AM" and the "Alert rules" link;
  add "Stop flagging" to each card.
- `Main` and `Report`: drop the "weekly" framing and date range; the list is
  current, not a Monday snapshot.

## Constraints

- Local-first: computed on device from stored sessions; no network.
- Only roster members are flagged; guest marks never are. To make the two
  newcomer rules work, "Add someone" in the marking grid adds to the roster
  by default, with "mark as a one-off guest" as the secondary choice.
- Follow-up ticks and stop-flagging choices are stored with the event data
  so they survive backup and restore.
- Fluid Humanist design system; WCAG AA (dot states differ by fill and
  outline, not hue alone).
- Tests with the code; coverage above 95%.

## Left to the builder

- Where the rule constants live and how the computation is cached.
- Storage shape for follow-up ticks and stop-flagging.
- How "weeks" rules behave for events that meet less than weekly.

## Open question for real use

- Three rules overlap (Not coming recently, Sudden drop, Gone quiet). Kept
  as five because they come from the owner's attendance guide; revisit
  whether they collapse into one "dropped off" flag.
