# ADR 0009: Offline font asset bundling and coordinator age affirmation (COPPA)

- Status: Accepted
- Date: 2026-10-24

## Context

Under US COPPA (15 U.S.C. §§ 6501–6506) and general data privacy principles:
1. **Remote CDN Fetching**: Using `package:google_fonts` without bundled assets triggers dynamic HTTP requests to Google CDN at runtime. On web builds and networked mobile devices, this leaks user IP addresses and metadata, violates zero-leak privacy principles, and leads to font flickering ("font-pop") or rendering glitches in air-gapped / offline environments.
2. **COPPA Direct Child Access**: COPPA applies to operators collecting personal identifiers directly from children under 13. Attendance Tracker is an administrative tool operated by adult event organizers and coordinators to maintain rosters and record attendance marks. Because children do not create accounts or directly enter information, a child-facing interactive birth-year gate is unnecessary and creates user friction. However, affirmative verification of adult coordinator status during onboarding formalizes the boundary and ensures regulatory clarity.

## Decision

1. **Local Font Asset Bundling**:
   - Bundle all required font weights for **Fraunces** and **Geist** in `assets/fonts/`.
   - Register the fonts under `flutter: fonts:` in `pubspec.yaml`.
   - Explicitly configure `GoogleFonts.config.allowRuntimeFetching = false` during application startup (`main.dart`), enforcing offline-first zero-leak font resolution.

2. **Coordinator Age Affirmation**:
   - Rather than an interactive birth-year picker blocking app launch, the onboarding experience explicitly presents a coordinator age affirmation: verifying that the operator is at least 13 years old (or an authorized adult coordinator) before proceeding to local workspace creation.
   - Record the affirmation status alongside existing onboarding flags in `SharedPreferences`.

## Alternatives considered

| Alternative | Why we passed |
| --- | --- |
| **Dynamic CDN fetching with web-only overrides** | Inconsistent across platforms; fails in full offline flight mode; leaks client IP addresses to CDN servers. |
| **Interactive birth-year selector during onboarding** | High friction; Attendance Tracker is an organizer-facing utility where coordinators record marks for groups, not a child-facing social network or student self-service app. |

## Consequences

### Positive
- Fully hermetic, offline font rendering with zero network latency or font-pop.
- Strict compliance with zero-third-party IP leakage across all platforms (web, desktop, mobile).
- Clear legal posture and transparency regarding COPPA and authorized adult coordinator usage.

### Negative
- Increases app binary size by bundling font weight files in assets.
