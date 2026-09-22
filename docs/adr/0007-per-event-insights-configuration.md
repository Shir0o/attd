# 0007. Insights Configuration Lives on the Event

## Context
Insights thresholds are not universal: "attended at least 80% of the last 8 sessions" is a reasonable bar for a weekly class and a meaningless one for a monthly meeting. Users asked for the **Regular** threshold, the **Lapsed Attendee** rule, the viewing range, and section visibility to be configurable.

This sits in tension with the deliberate constraint that Insights be purely derived — recomputed on read from sessions and members, adding no new persisted state and no new file to the Drive sync merge path. Configuration is, unavoidably, persisted state.

## Decision
**Insights Configuration** is stored as discrete nullable fields on `Event`, alongside the existing `rosterGrouping`, `markingMode`, and `defaultAttendanceStartMode` presets.

The tension resolves on a distinction worth stating plainly: a **preset is not derived data**. The constraint was about not persisting computed results — which would create a second, staleable source of truth for numbers the app can always recompute. A threshold is an input to that computation, not an output of it, and `Event` already carries three such presets through `events.json` and the existing merge path. No new synced file, no new merge behaviour, and the fields are additive and nullable exactly as `markingMode` was.

Configuration is edited from a Customize sheet on the Insights page rather than the Edit Event page, because tuning a threshold and watching the affected list change is the whole interaction. On a **Shared Event** the user does not own (`event.isReadOnly`), the configuration renders read-only.

## Considered Options
- **`SharedPreferences`** — device-local, app-wide, no schema change, no sync involvement. Rejected: thresholds are a property of the event, not of the phone, and per-event scope was a requirement. More importantly, device-local settings that silently change what a word *means* are how a **Share Collaborator** and an owner end up reading the same label — "Regular" — as two different numbers while looking at what appears to be the same screen.
- **A single JSON blob field on `Event`.** Rejected: the Drive merge in `drive_service.dart` operates per file and resolves last-write-wins, so a blob makes one person's threshold tweak silently revert another's section toggle. Discrete fields keep the conflict surface at the granularity of the individual setting.
- **A new synced configuration file.** Rejected: a new file in the merge path is exactly the cost the derived-only constraint was protecting against, for data that has a natural home on an existing synced entity.

## Consequences
- Metric definitions travel with the event through backup, restore, and sharing, so the numbers mean the same thing wherever the event is opened.
- Defaults live in the resolution accessors (mirroring `Event.resolvedMarkingMode`), so existing events pick up sensible values with no migration.
- `Event` continues to accumulate presentation-adjacent presets. Should this grow much past the current set, extracting a preset value object is the natural next step.
