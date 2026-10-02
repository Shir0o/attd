# 0008. Shared-Element Motion for Primary Actions over Snapping Pages

## Context
The app deliberately snaps between pages: `NoTransitionsBuilder` is installed for every platform, because the editorial layout reads better when screens do not slide or fade. The cost is that the violet primary controls (the Hub **+**, **Create event**, **Add someone**, **Confirm N present**) hand the user from one surface to the next with no visual link to the control they just touched, and pressing them gives no tactile feedback.

Two facts shape what is possible:
- Under `NoTransitionsBuilder`, `MaterialPageRoute` still runs its 300 ms route animation; only the visual slide is removed. That is why the Hub FAB to Create event `Hero` already flies, and why connecting the two needs no route changes.
- Heroes only fly between page routes, and `OpenContainer` (the `animations` package) only pushes full-screen routes. Neither can fly into a modal bottom sheet.

## Decision
Pages keep snapping. The violet element the user touched is allowed to visibly *become* the next thing, on top of an otherwise instant page or sheet change:
- Shared-element flights (a `Hero` with an arc `createRectTween` and a `flightShuttleBuilder`) for page-to-page handoffs. The first is the Hub FAB to the Create event pill: the corner radius tweens from the FAB squircle to the pill's stadium, the + icon fades out and the label fades in, and the label is never wrapped or laid out in a box narrower than its intrinsic width.
- In-surface press feedback (`ConvPressable`) on every violet primary pill and FAB.
- Three shared motion tokens in `AppMotion`: `morph` (400 ms, `Cubic(0.05, 0.7, 0.1, 1)`) for container transforms and shared elements, `house` (220 ms, `Cubic(0.2, 0.7, 0.3, 1)`, the existing toggle curve) for in-surface changes, and `exit` (200 ms, `Cubic(0.3, 0, 0.8, 0.15)`) for dismissals.
- A single helper, `motionEnabled(context, disableAnimations: ...)`, decides whether any of this runs. It is false when the widget's existing `disableAnimations` flag is set *or* when the system "Remove animations" setting (`MediaQuery.disableAnimationsOf`) is on. When it is false, every surface behaves exactly as it did before: no `Hero`, no transform, no shuttle.

No new packages are added. Bottom-sheet morphs (a later step) use a small custom route instead of a `Hero` or `OpenContainer`, for the reasons in Context.

## Considered Options
- **Re-enable page transitions.** Rejected: it contradicts the snapping design, slows the attendance flow, and animates the wrong thing (the whole page rather than the control the user touched).
- **The `animations` package (`OpenContainer`).** Rejected: it only pushes full-screen routes, so it cannot morph a control into a bottom sheet, and it adds a dependency for one effect.
- **Leave the existing Hub Hero as is.** Rejected: mid-flight the squircle snaps to a circle and the label is crushed into the FAB's 40 px box, which reads as a glitch rather than a handoff.
- **Gate on the test flag only.** Rejected: the system "Remove animations" setting must be honoured, and one helper keeps the flag and the setting from drifting apart.

## Consequences
- Pages still appear instantly; the exception is limited to the violet element that was touched. New motion must be built from the `AppMotion` tokens and gated by `motionEnabled`.
- Reduce-motion users, and every existing widget test that passes `disableAnimations: true`, get today's behaviour unchanged.
- The Hub FAB `Hero` is now wrapped by the app (not `FloatingActionButton`'s internal one) so both flight directions share the arc tween; the Add Event pill supplies the shuttle for both.
- Future flights between a FAB and a pill can reuse `convArcRectTween` and `convFabPillShuttleBuilder`.
