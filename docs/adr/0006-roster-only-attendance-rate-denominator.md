# 0006. Roster-Only Denominator for Attendance Rate

## Context
`SessionRoster` promotes any attendee without a matching roster member into the session's display map as a visitor (`isVisitor: true`). The two Insights surfaces then disagreed about whether those people count: `EventTrendPage` iterated `roster.sortedMembers` and so counted guests in both the present numerator and the total denominator, while `ConsistentMembersPage` iterated the member list and never saw them at all. The same event produced two different attendance rates depending on which screen you opened.

A **Guest Mark** exists only when someone was actually marked present — there is no mechanism by which a guest is recorded absent. Including guests in the denominator therefore adds a row that can only ever resolve to "present", which drags the rate upward for a reason unrelated to attendance. An event with a steady roster and growing guest traffic would show an improving attendance rate while roster attendance was flat or falling.

## Decision
**Attendance Rate** is present marks over expected *roster members*. Guests are excluded from both numerator and denominator of every rate in Insights.

Guests are not discarded: they are the subject of their own metrics (guest count and guest trend, first-timers), where a raw count is the honest presentation. The exclusion is scoped to rates specifically, not to Insights as a whole — a first-timer is almost always an unrostered attendee, so excluding guests everywhere would render those sections empty by construction.

Relatedly, a late mark continues to count as a full present and never moves this number, consistent with the existing invariant in `ReportSummary.lateCount` and `DESIGN_SPEC.md`. Lateness is reported as its own rate. Neither of these is user-configurable, so that the same event's history cannot read differently for two people looking at it.

## Considered Options
- **Count guests in both numerator and denominator** (make `ConsistentMembersPage` match `EventTrendPage`). Rejected: it preserves the upward drift described above and makes "attendance rate" answer a question nobody asked — it stops meaning "how much of my roster showed up" without meaning anything else in particular.
- **Leave the inconsistency in place** and scope the work to new metrics only. Rejected: every new metric would have had to pick a side anyway, and the disagreement would have multiplied rather than been resolved.

## Consequences
- Attendance rates shown for events with guest traffic will be **lower** than the numbers previously displayed on `EventTrendPage`. This is a corrected number, not a regression, but it is a visible change to historical figures.
- The denominator is defined exactly once, in the single `EventInsights` computation, rather than independently per section. This is the structural reason the two surfaces cannot drift apart again.
- Rates published to a **Share Collaborator** now mean the same thing on both sides of the share.
