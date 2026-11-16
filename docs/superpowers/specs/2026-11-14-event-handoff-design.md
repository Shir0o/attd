# Event handoff — design

Status: draft, design only. Not scheduled for implementation; to be validated
in real use when built. Date: 2026-11-14. Supersedes the approach in
ADR 0005 (scoped Google Drive subfolder sharing).

## Intent

The owner sometimes cannot take attendance and needs another person to mark a
session on their behalf, on that person's own phone, without handing over the
owner's phone and without giving up the app's local-first, privacy-first
model.

This is delegation, not collaboration: a roster goes out, marks come back.

## Why the current feature is replaced

"Share Event" models the need as ongoing multi-user collaboration: Google
accounts, email invitations, Drive permissions, two-way background sync, and
merge rules.

- It very likely does not work. The app requests only the `drive.file` scope,
  which exposes files this app created for this user. Collaborators discover
  shared events with a `sharedWithMe` folder query, which that scope will not
  satisfy for a folder created under another user's authorization. (Read from
  code and Drive's scope rules; never exercised with two accounts.)
- Repairing it needs the full Drive scope, a restricted scope requiring
  Google's security assessment — wrong for a privacy-first app.
- The owner has never used it and cannot describe what it does.

## Goals

- A helper can mark one session for the owner on their own phone.
- No account, no server, no background sync. Works offline.
- Only what the helper needs leaves the owner's phone, and only to a
  recipient the owner picks.
- The helper uses the same marking grid; nothing new to learn.

## Non-goals

- Live or simultaneous marking across devices.
- Ongoing shared ownership of an event, collaborator lists, revocation.
- Helpers editing the event, the roster, or past sessions.
- A no-install web version for helpers (revisit only if installing the app
  proves to be the real obstacle).

## Anti-goals

- Anything requiring a broader Google permission or a backend.
- Sending member details beyond display names.

## Approaches considered

1. **One-shot handoff file (chosen).** Owner sends a small file through the
   system share sheet; helper marks and sends a result file back; owner
   imports it. No infrastructure. Costs: helper installs the app once; two
   manual sends; nothing arrives if the helper never sends back.
2. **Repair Drive sharing.** Live sync, but needs the restricted scope and
   keeps ~1,300 lines of the least testable code in the app.
3. **Hosted web page for the helper.** No install, but adds hosting and a
   second marking surface to maintain.
4. **Cut the feature; hand over the phone.** Rejected: this is the case the
   owner needs to avoid.

## Design

### Flow

```
Owner:   Event menu → Hand off → system share sheet → send file
Helper:  open file in the app → event appears → Start → grid → Done → Send back
Owner:   open returned file → review summary → Add to session
```

### Owner: hand off

- "Hand off" replaces "Share Event" in the event menu.
- One short explainer line, then the system share sheet with the handoff
  file attached. No setup, no recipient list kept in the app.
- The file contains: a format version, the event id and title, the session
  date being handed off, and the roster as `{member id, display name}` only.
  No families, notes, history, or other events.

### Helper: receive and mark

- Opening the file in the app adds the event to the hub, visibly labelled as
  someone else's (replacing today's "SHARED" badge), with edit, delete,
  roster, and history actions unavailable.
- Start opens the standard marking grid. "Add someone" records a guest mark;
  it never creates a member.
- Done leads straight to "Send back", which opens the share sheet with the
  result file. The result holds the event id, session date, marks (member id,
  status, recorded-at), guest marks, and an optional helper name.
- After sending, the helper can remove the handed-off event; nothing of the
  owner's data needs to stay on their phone.

### Owner: import the result

- Opening the result file shows a summary before anything changes: event,
  date, who marked (if given), counts present, and any guests.
- "Add to session" merges into the session for that event and date, creating
  it if absent. Existing merge rule applies: present beats absent; otherwise
  the later mark wins. Marks carry the helper as actor.
- A result whose event id is unknown, or whose member ids no longer exist, is
  not silently dropped: unknown members import as guest marks by name, and an
  unknown event is refused with a clear message.

### Trust and safety

- Files are plain, unencrypted data chosen by the owner to send; say so in
  the explainer line.
- Incoming files are untrusted input: validate version, shape, and size
  before use; never execute or follow anything in them.

### What is reused and what goes

- Reused: the shared slice (event, names, sessions) and the tested mark-level
  merge in `shared_event_sync.dart`.
- Removed: the Share sheet and collaborator management, the Drive transport,
  shared-folder discovery, the shared-event calls in background sync and hub
  load, and the "SHARED" badges. ADR 0005 is marked superseded by a new ADR.

## Constraints

- Local-first; no new permissions beyond opening and sharing a file.
- Fluid Humanist design system; one new menu action, no new settings.
- Tests with the code; coverage above 95%.

## Risks to validate in real use

- Whether tapping the file in common messaging apps reliably opens the app on
  Android. If not, an "Open handoff file" picker entry is the fallback.
- Whether helpers actually send the result back, and whether the two manual
  sends feel acceptable.
- Whether installing the app is too much to ask of a one-time helper.

## Left to the builder

- File extension, MIME type, and how the app registers to open it.
- Whether the helper's name is asked once or left blank.
- Exact wording of the explainer and summary screens.
