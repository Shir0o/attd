# ADR 0003: Tiered error handling and privacy-first crash reporting

- Status: Accepted
- Date: 2026-09-06

## Context

As the application expanded with Google Drive synchronization, biometric authentication, and local JSON backup/restore, unhandled exceptions and failures required a structured strategy:
1. **Developer visibility**: In production, unhandled runtime errors were not tracked remotely, relying solely on local debug output.
2. **Privacy focus**: As a privacy-focused application handling attendance and personal roster records, silently enabling third-party telemetry without user knowledge and explicit consent violates user expectations.
3. **User feedback**: Unhandled widget exceptions could render standard Flutter red/grey error boxes, while transient network or sync issues lacked a consistent, design-system-aligned feedback mechanism.

## Decision

We establish an end-to-end, privacy-first error catching, reporting, and presentation architecture:

1. **Typed Domain Exception Hierarchy (`AppException`)**:
   - Repository and service operations throw structured subclasses of `AppException` (e.g. `SyncException`, `StorageException`, `AuthFailureException`).
   - Every exception encapsulates a sanitized, user-facing message, an optional recovery suggestion, and technical context for diagnostics.

2. **Abstracted `CrashReportingService` with Explicit Opt-In Consent**:
   - Crash reporting is decoupled behind an abstract `CrashReportingService` interface with `FirebaseCrashReportingService` and local/no-op implementations for testing.
   - **Default OFF**: Remote crash collection is disabled by default. On first launch, the app prompts the user for diagnostic telemetry consent (mirroring the system permission model).
   - Users can toggle consent at any time in Settings.
   - Strict PII scrubbing: Roster names, attendee IDs, and personal notes are never attached to crash breadcrumbs or custom keys.

3. **Two-Tiered Framework Catching**:
   - Global runtime capture via `PlatformDispatcher.onError` and `FlutterError.onError` forwarding to `CrashReportingService`.
   - Global `ErrorWidget.builder` presenting a friendly, Fluid Humanist recovery card rather than crashing the interface.
   - Feature-level `ErrorBoundary` widgets for high-risk dynamic views (e.g. hub view, roster view) to isolate render failures without bringing down the navigation hierarchy.

4. **Fluid Humanist User Feedback Components**:
   - `AppErrorFeedback.showSnackBar`: Tonal pill snackbars for transient non-blocking failures with optional retry actions.
   - `AppErrorFeedback.showDialog`: Modal recovery dialogs for blocking operations requiring user intervention.
   - `AppErrorView`: Inline state view replacing failed content with an explanatory message and retry button.

## Alternatives considered

| Alternative | Why we passed |
| --- | --- |
| **Telemetry enabled by default in release** | Violates the core value proposition of a privacy-focused local-first application. Users must retain explicit agency over diagnostic data sharing. |
| **Result<T, Failure> (Either pattern)** | Introduces boilerplate and friction across async Flutter/Dart APIs; typed exceptions paired with uniform UI catchers provide clean ergonomics while ensuring errors are handled. |
| **Unstyled raw SnackBar calls** | Inconsistent styling and violates the Fluid Humanist design principles defined in `DESIGN_SPEC.md`. |

## Consequences

### Positive
- Production crashes can be diagnosed while strictly preserving user privacy and transparency.
- Predictable, polished user experience during unexpected errors without red screen crashes.
- High testability: all error reporting and presentation can be tested via mocks without native Firebase dependencies.

### Negative
- With opt-in telemetry defaulting to off, fewer production crash traces will be collected compared to an opt-out model.
