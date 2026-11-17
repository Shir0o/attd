# ADR 0011: One-Shot Event Handoff Replaces Drive Sharing

- Status: Accepted
- Date: 2026-11-16
- Supersedes: [ADR 0005](0005-scoped-google-drive-subfolder-sharing.md)

## Context

"Share Event" (ADR 0005) modelled the need as ongoing collaboration: Google
accounts, Drive permissions, two-way background sync. It very likely never
worked. The app requests only the `drive.file` scope, which cannot see a folder
another user shared; repairing that needs the full Drive scope, a restricted
scope with a security assessment, which is wrong for a privacy-first app. The
owner never used it.

The real need is delegation: someone else marks one session on the owner's
behalf, on their own phone. A roster goes out, marks come back. See the
[event handoff design](../superpowers/specs/2026-11-14-event-handoff-design.md).

## Decision

1. **A handoff is a file, not a connection.** The owner sends a small plain
   file through the system share sheet; the helper marks and sends a result
   file back; the owner opens it. No account, server, sync or permission beyond
   opening and sharing a file. It works offline.
2. **Two documents, one format.** `.attdhandoff`, MIME
   `application/vnd.attd.handoff+json`, JSON, `version: 1`, `kind` of
   `handoff` (event id and title, the session date, roster as `{id, name}`) or
   `result` (event id, session date, marks, guest marks, optional helper name).
   Nothing else leaves the owner's phone: no families, notes, history or other
   events. The file is unencrypted and the owner is told so before sharing.
3. **Incoming files are untrusted.** Size is capped before parsing; version and
   exact shape are validated; list and string lengths are bounded; extra keys,
   control characters and unknown values are rejected. Nothing in a file is
   executed, followed or used in a path.
4. **A file cannot touch the receiver's own data.** Ids from a handoff are
   stored with a `handoff:` prefix, which this app never generates and the
   decoder rejects in incoming ids. The helper's copy of a roster is one family
   with the same namespaced id as the event, so removing a handed-off event
   removes exactly what it brought.
5. **The helper's event is explicitly someone else's.** `Event.handoffEventId`
   marks it. Edit, roster, history and hand-off are unavailable, "Add someone"
   only records a guest mark, and Done leads to "Send back". Handed-off events
   are left out of "Who to check on" and of reminders.
6. **Importing reuses the mark-level merge.** Present beats absent; otherwise
   the later mark wins. The helper is recorded as the actor. A result for an
   unknown event is refused; marks for members who no longer exist import as
   guest marks by name; importing the same result twice changes nothing. The
   owner reviews a summary and nothing changes until "Add to session".
7. **Getting the file in.** Android registers the app to open the file (tapped
   attachment or share target). Because messaging apps do not reliably route
   attachments, an in-app "Open handoff file" picker is the fallback and the
   only route on iOS.

## Consequences

- About 1,300 lines of the least testable code (Drive transport, folder
  discovery, sync coordinator, collaborator management) are gone, along with
  the `isShared`, `sharedFolderId`, `collaborators` and `isReadOnly` event
  fields. Old data containing them still loads; the keys are ignored and no
  longer written. An event once marked shared is now an ordinary event.
- Two manual sends per handoff, and nothing arrives if the helper never sends
  back. The helper must install the app once.
- One new dependency, `file_picker`, for the fallback picker.
- Removing a handed-off event uses the app's usual soft delete, so its records
  are purged with other deletions after 90 days.
- Not exercised on a device when written; see the design's "Risks to validate
  in real use".
