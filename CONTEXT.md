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
An attendance mark whose member-ID link references a member that no longer exists (deleted or missing from the roster). Flagged in the storage inspector, but it is attendance history, so bulk cleanup removes it only when explicitly opted in.
_Avoid_: Dangling record, broken reference

**Tombstone**:
A soft-deleted record (`deletedAt` and `updatedAt` set) kept so that Drive sync propagates the deletion instead of re-adding the record from the cloud copy. Storage-inspector cleanup writes tombstones rather than removing records; data maintenance prunes tombstones after 90 days. Tombstones are not cleanup issues.
_Avoid_: Hard delete, purge

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
An attendance mark recorded for an attendee not found on the Shared Event's roster, preserving the attendee name snapshot with a null member ID for the session without mutating the owner's master roster. Legitimate attendance: never flagged by the storage inspector.
_Avoid_: Walk-in, temporary member, unlisted attendee, unlinked mark

**Insights**:
The per-event analytics surface presenting attendance trends, people views, and attendance-quality metrics as a single configurable stack of sections. Reached from the Hub event card and the Hub event menu; scoped to one event at a time.
_Avoid_: Stats, analytics dashboard, reports

**Attendance Rate**:
Present marks divided by the count of roster members expected at a session. Guests are excluded from the denominator, because a Guest Mark can never be absent and would only ever push the rate upward. A late mark counts as a full present and never moves this number.
_Avoid_: Turnout percentage, show rate

**Regular**:
A member meeting an event's configured consistency threshold across the most recent window of sessions (default: attended at least 80% of the last 8). The threshold and window are per-event Insights Configuration, not global constants.
_Avoid_: Consistent member, faithful attendee, core member

**Lapsed Attendee**:
A member who qualified as a Regular across the prior window and has since missed a configured number of consecutive sessions (default 3). Requires a minimum of prior sessions (default 4) before any verdict is rendered; below that the section reports insufficient data rather than a false negative. The inverse of a Regular, and distinct from a member who was never consistent.
_Avoid_: At-risk member, inactive member, dropout, watchlist

**First Seen**:
The date of the earliest non-deleted session of an event carrying a mark for a person. Derived on read, never stored. Only as old as the recorded data, so a person who attended before the app was adopted reads as newly seen at their next mark.
_Avoid_: Join date, member since, signup date

**Insights Configuration**:
The per-event presets governing what Insights computes and shows — viewing range, Regular threshold and window, Lapsed rule, and section visibility — stored on the Event beside the existing roster grouping and marking mode presets. A preset, not derived data. Read-only on a Shared Event the user does not own.
_Avoid_: Stats settings, dashboard preferences
