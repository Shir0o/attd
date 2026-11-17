# Attendance Tracker

A privacy-focused local-first attendance and membership management app with cloud backup capabilities.

## Language

**App Failure**:
A modeled domain representation of an operation that did not succeed, capturing both technical cause and a user-facing resolution message.
_Avoid_: Error object, raw exception

**Crash Reporting**:
The privacy-respecting automated mechanism for recording fatal and uncaught runtime exceptions to remote telemetry only when explicitly opted into by the user, and logging locally in development.
_Avoid_: Bug tracker, analytics

**Transient Failure**:
An error caused by temporary external conditions (e.g. temporary network offline during Drive sync) that does not invalidate local state and can be communicated unobtrusively.
_Avoid_: Network glitch, soft error

**Blocking Failure**:
An error that stops a user from completing their intended action (e.g. corrupt backup file parse, failed biometric gate) requiring explicit user acknowledgment or action.
_Avoid_: Hard error, fatal exception

**Crash Reporting Consent**:
The explicit user permission prompt (defaulting to off) requested upon first app launch or toggled in Settings allowing diagnostic telemetry collection without PII.
_Avoid_: Tracking opt-in, telemetry flag

**Attendance Mark**:
A single attendance record: a person, a status (present/absent), a recorded-at timestamp, and the actor who recorded it. Stored inside a Session; links to a person by stable member ID with a denormalized name snapshot.
_Avoid_: Attendance entry, attendance row

**Orphaned Mark**:
An attendance mark whose member-ID link references a member that no longer exists (deleted or missing from the roster). Flagged as a Review Suggestion; it is attendance history, so the user links it to a live member, keeps it as a Guest Mark, or deletes it.
_Avoid_: Dangling record, broken reference

**Tombstone**:
A soft-deleted record (`deletedAt` and `updatedAt` set) kept so that Drive sync propagates the deletion instead of re-adding the record from the cloud copy. Storage-inspector deletions write tombstones rather than removing records; data maintenance prunes tombstones after 90 days. Tombstones are not Review Suggestions.
_Avoid_: Hard delete, purge

**Review Suggestion**:
A storage-inspector flag (duplicate, orphaned, empty) shown with the context needed to judge it: the mark's session, other sessions for the same event and date, same-name live members. Never acted on automatically; the user edits, deletes, or dismisses it ("Not an issue", remembered on that device).
_Avoid_: Bulk cleanup, auto-clean, flagged record

**Attendee Surname**:
The last whitespace-delimited token of an attendee's display name, shown as the subtitle under each name tile on the marking grid to tell apart people who share a given name. Where the Attendee Surname is displayed as the subtitle, the tile title shows only the attendee's given name(s); single-token names show their full name in the title and omit the surname subtitle.
_Avoid_: Family name fallback, attendee tail

**Static History Snapshot**:
The invariant that historical SessionRecords preserve the exact attendee name and member ID captured at recording time. Routine roster edits (such as renaming or deleting a member) do not automatically mutate past attendance sessions.
_Avoid_: Dynamic name resolution, historical cascade

**Bulk Name Merge**:
An intentional, explicit administrative operation that consolidates two attendee names or members across both the roster and past attendance records, with automatic collision resolution when both names co-occur in the same historical session.
_Avoid_: Silent name replace, cascade delete

**Dry-Run Validation**:
A read-only simulation executed prior to any bulk mutation or duplicate cleanup that calculates and displays the exact count of roster members altered, past session marks rewritten, and collision marks pruned.
_Avoid_: Unverified cleanup, blind migration

**Duplicate Pruning**:
The idempotent removal of redundant attendance marks (matching event title, session date, and attendee name) or duplicate member profiles (including ones stored in different Family Records), retaining exactly one canonical record.
_Avoid_: Mass wipe, duplicate purge

**Handoff**:
A one-shot delegation of one session of one event: the owner sends a plain file holding the event name, the session date and the roster names; the helper marks on their own phone and sends a Handoff Result back. No account, server or sync.
_Avoid_: Shared event, collaboration, co-recording

**Handed-off Event**:
An event on the helper's phone that came from someone else's Handoff, marked `handoffEventId`. It can be marked and sent back, never edited, and its roster lives under namespaced ids so it can be removed without touching the helper's own data.
_Avoid_: Shared event, read-only event, borrowed event

**Handoff Result**:
The file the helper sends back: event id, session date, marks (member id, name, status, recorded-at), guest marks and an optional helper name. The owner reviews it, then merges it into the session for that event and date.
_Avoid_: Sync, shared slice

**Member Directory**:
Every member the user knows, across all events. A person in the Member Directory is not expected at any particular event until they are on that event's Event Roster.
_Avoid_: Global roster, all members, master roster

**Event Roster**:
The members expected at one event; the people Who to Check On evaluates. Adding someone from the Member Directory to an event puts them on its Event Roster; a brand-new person added to the roster is created in the Member Directory and the Event Roster together.
_Avoid_: Roster (unqualified), event members, attendee list

**Guest Mark**:
An attendance mark recorded for an attendee not on the event's roster (any event, including a Handed-off Event, where it is the only way to add someone), preserving the attendee name snapshot with a null member ID for the session without adding them to the roster. Adding someone to the roster instead creates a member, not a Guest Mark. Legitimate attendance: never flagged by the storage inspector.
_Avoid_: Walk-in, temporary member, unlisted attendee, unlinked mark

**Who to Check On**:
The hub card and report that flag Event Roster members who may need a follow-up, using five fixed rules (Not coming recently, Sudden drop, Gone quiet, Newcomer follow-up, One-time visitor). The numbers are the same for every event and there are no settings. Only roster members are evaluated, from their present marks in the event's sessions; Guest Marks are never flagged. Derived on read, never stored.
_Avoid_: Insights, analytics, watchlist, at-risk list

**Family Record**:
Storage only: the container (`families.json`) in which members are stored. A person without a household lives in an auto-singleton Family Record of their own. The app has no family screens and no family marking or grouping; people are marked and listed individually.
_Avoid_: Household, loner, family marking

**Attendance Marking Session**:
The in-process domain module and state coordinator governing active attendance recording, optimistic persistence serialization, undo history, and member/guest identity resolution for a session.
_Avoid_: Marking state, attendance controller, marking manager

**Storage Inspector**:
The diagnostic engine that scans repository data for Review Suggestions, tombstones, orphaned records, and duplicate collisions without dynamic casts into storage implementations.
_Avoid_: Cleanup tool, DB cleaner, backup manager

**Active Roster Index**:
The in-memory name index derived from an Event Roster: the given name and Attendee Surname of each member for the marking grid, and the substring matching behind the session summary's search. Roster order is alphabetical; there is no likelihood ranking.
_Avoid_: Search helper, initials indexer, likelihood cache

**Cloud Snapshot**:
A point-in-time archive of the app's repositories stored in Google Drive only when sync detects actual data changes (or prior to a destructive recovery action), annotated with a bounded list of the exact domain items changed and subject to automatic retention thinning.
_Avoid_: Version history zip, raw backup file

**Snapshot Thinning**:
The automatic retention policy that prunes older Cloud Snapshots over time (preserving recent snapshots, daily rollups within 30 days, and a minimum safety floor) and caps per-session version history to prevent unbounded cloud and local storage bloat.
_Avoid_: Manual backup cleanup, unbounded history

**Force Overwrite**:
An explicit recovery action that unilaterally replaces either local device data with the cloud copy or the cloud copy with local device data, always preceded by a safety Cloud Snapshot.
_Avoid_: Hard reset, blind overwrite

**Coordinator Age Affirmation**:
The explicit onboarding declaration where an operator confirms they are at least 13 years of age or an authorized adult coordinator managing attendance records, establishing compliance with COPPA boundaries before access to local roster features.
_Avoid_: Age gate, birth-year screen, child check



**Attendance Reminder**:
A local notification scheduled to alert coordinators when attendance has not yet been marked for a scheduled event. Configured with a single global on/off switch and always fires 1 hour after the scheduled event start time, automatically suppressed or dismissed if attendance marks already exist for that event on that date.
_Avoid_: Push notification, attendance alarm, event ping
