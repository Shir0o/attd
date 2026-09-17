# ADR 0004: Static Attendance History and Explicit Bulk Name Merge with Dry-Run

- Status: Accepted
- Date: 2026-09-17

## Context

In Attendance Tracker, `SessionRecord` entries store a denormalized `attendee` string name snapshot alongside an optional `memberId`. Historically, routine member edits in the roster (e.g. updating a member's display name or moving a member between families) did not propagate to past attendance records. This preserves the static snapshot principle: an attendance mark is an audit record of who was present at that specific point in time.

However, organizations frequently encounter data-quality issues:
1. **Name Evolution & Typos**: A visitor was marked as "Bob Smith" across 12 sessions before formally joining as "Robert Smith".
2. **Duplicate Person Profiles**: Two members represent the same physical person in different families or due to duplicate entries.
3. **Redundant Duplicate Marks**: Fast-marking retries or sync merges may create multiple duplicate attendance entries in the same session.

Users need an explicit, safe mechanism to bulk-rename attendees, merge two person identities into one across past history, and prune duplicate records, without violating the guarantee that everyday roster changes never silently alter historical logs.

## Decision

We establish three architectural principles:

1. **Static History Invariant as Default**:
   - Routine roster changes (renaming, deleting, family reassignments) never mutate historical `Session` or `SessionRecord` entries.
   - Attendance history remains an immutable log unless the user invokes the dedicated Bulk Maintenance tool.

2. **Explicit Bulk Name Merge & Rename with Dry-Run Validation**:
   - Merging or renaming across historical sessions is isolated to an explicit administrative service (`BulkMaintenanceService`).
   - Prior to any mutation, a **Dry-Run Validation** simulation is computed and displayed to the user:
     - Number of roster members affected / merged.
     - Number of past `SessionRecord` marks rewritten.
     - Number of intra-session collision duplicates detected (where both Source and Target were marked in the same session).
   - On confirmation, the merge:
     - Updates matching historical `SessionRecord` attendee names and member IDs.
     - Prunes duplicate collisions within any single session (retaining the primary mark).
     - Consolidates roster members by removing or soft-deleting the source member and retaining the target.

3. **Validated Duplicate Pruning**:
   - Both session duplicate marks (matching event title, session date, and attendee name) and roster duplicate profiles across families have automated validation and dry-run summaries before cleanup.

## Alternatives Considered

| Alternative | Why we passed |
| --- | --- |
| Dynamic pointer resolution (resolve attendee names from `memberId` dynamically) | Violates static audit trail; historical attendance records change retroactively if a member is renamed or deleted. |
| Automatic cascade on roster rename | Surprising and risky; renaming a current member could unintentionally rewrite years of historical archives. |
| Unverified bulk migration | High risk of unintended data destruction; users cannot see collision counts or affected sessions before committing. |

## Consequences

### Positive
- Strict audit integrity: historical logs stay static by default.
- Complete transparency: users see exact counts and dry-run diffs before any bulk rewrite.
- Safe collision handling: merging two records that both attended the same session collapses into one valid mark rather than corrupting session statistics.

### Negative
- Requires a dedicated administrative UI flow and simulation logic.
- Requires atomic multi-repository persistence (sessions + families).
