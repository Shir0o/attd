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
