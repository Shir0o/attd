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
A single attendance record: a person, a status (present/absent/late), a recorded-at timestamp, and the actor who recorded it. Stored inside a Session; links to a person by stable member ID with a denormalized name snapshot.
_Avoid_: Attendance entry, attendance row

**Orphaned Mark**:
An attendance mark whose member-ID link references a member that no longer exists (deleted or missing from the roster). Flagged in the storage inspector and cleanable in bulk.
_Avoid_: Dangling record, broken reference

**Unlinked Mark**:
An attendance mark with no member-ID link (memberId is null) whose attendee name matches no active member. Distinct from an Orphaned Mark: the link is absent rather than dangling. Flagged in the storage inspector and cleanable in bulk.
_Avoid_: Attendance without a person, nameless record

**Attendee Surname**:
The last whitespace-delimited token of an attendee's display name, used across marking modes (such as Likely Here chips and fast-marking subtitles) to disambiguate attendees and replace generic "NEW" or "Loner" labels when attendance history or household groupings are absent.
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
The idempotent removal of redundant attendance marks (matching event title, session date, and attendee name) or duplicate member profiles across families, retaining exactly one canonical record.
_Avoid_: Mass wipe, duplicate purge

**Shared Event**:
An event whose roster and attendance marking sessions are scoped and published to a shared cloud folder, granting another Google user permission to co-record attendance.
_Avoid_: Co-worker event, team event

**Shared Slice**:
The isolated data payload containing only the specific event definitions, linked member profiles, and session marks required for a Shared Event, strictly excluding unshared events and private notes.
_Avoid_: Database export, partial backup

**Share Collaborator**:
A Google account authorized to view a Shared Event and record attendance marks within its sessions.
_Avoid_: Co-worker, sub-user, assistant taker

**Guest Mark**:
An attendance mark recorded for an attendee not found on the Shared Event's roster, preserving the attendee name snapshot with a null member ID for the session without mutating the owner's master roster.
_Avoid_: Walk-in, temporary member, unlisted attendee
