---
type: Wiki Guide
title: Attendance Tracker Wiki
description: Entry point for the OpenWiki documentation covering architecture, features, design system, testing, integrations, and operations for the Attendance Tracker Flutter app.
---

# Attendance Tracker Wiki

**A modern, fast, and privacy-focused Flutter application for tracking attendance, managing member engagement, and syncing data seamlessly with Google Sheets and Drive.**

This is a private, local-first attendance tracking application built with Flutter. All data lives on-device and in the user's personal Google Drive—no third-party servers ever see your data.

## What This Wiki Covers

- **Architecture & Data Model** — How the app is organized, what data is persisted locally, and how repositories manage Members, Families, Events, and Sessions
- **Key Workflows** — Attendance taking (quick marking, smart defaults, roster grouping), event management, member/family organization, insights (Regulars/Trends)
- **Google Integration** — Drive sync, Sheets export, OAuth flow, backup/restore
- **Testing & Quality** — Test structure, coverage thresholds (95%+), integration test robot framework
- **Design System** — The Convocation editorial design language: fonts, colors, components, motion
- **Operations** — Building, debugging, deployment, common issues

## Quick Start: First Time Here?

1. **New to the codebase?** Start with [Architecture Overview](/openwiki/architecture.md) to understand the feature-sliced structure and data flow.
2. **Want to work on a feature?** Check [Features & Workflows](/openwiki/features.md) for domain concepts, page flows, and source references.
3. **Making changes?** Review [Testing & Quality](/openwiki/testing.md) for coverage expectations and test patterns.
4. **Integrating with external services?** See [Integrations (Drive, Sheets, OAuth)](/openwiki/integrations.md).
5. **Troubleshooting issues?** Check [Operations & Runbooks](/openwiki/operations.md).

## Repository Structure at a Glance

```
lib/
├── main.dart                 # App entry, Firebase init, dependency injection
├── core/
│   ├── design/              # Design system (colors, typography, Convocation primitives)
│   ├── maintenance/         # Data pruning & housekeeping
│   ├── quick_actions/       # Home screen shortcuts
│   └── logging/             # Structured logging
├── data/
│   ├── session.dart         # Session domain model
│   ├── session_record.dart  # Individual attendance record (present/absent/etc)
│   ├── local_session_repository.dart  # Local JSON persistence
│   └── session_repository.dart        # Abstract repository interface
└── features/                # Feature-sliced architecture
    ├── auth/                # Google OAuth + local auth (app lock)
    ├── hub/                 # Dashboard, event listing, quick start
    ├── attendance/          # Quick marking deck, session summary
    ├── sessions/            # Insights: Regulars (80%+), Trends (sparkline)
    ├── families/            # Family grouping, member assignment
    ├── reports/             # CSV export (via Sheets integration)
    ├── settings/            # Cloud backup, version history, data inspector
    └── onboarding/          # 4-slide editorial introduction

test/
├── widget_test.dart         # UI/component testing
├── features/                # Feature-level unit tests
└── integration_test/        # E2E scenarios (robots pattern)

integration_test/
├── robots/                  # Fluent test helpers (HubRobot, EventRobot, etc)
└── utils/                   # Test fixtures & database seeding
```

## Core Concepts

### Data Model

**Members & Families** → Local JSON persistence (`families.json`). Members belong to Families (which can be auto-singletons for unassigned members or real family groupings). Prevents duplicates during data merge/sync.

**Events** → Created by the user (one-time or recurring with smart "Last Missed" detection). Events link to Members via `memberIds` and store a per-event `rosterGrouping` preset (By Status / By Family) and `defaultAttendanceStartMode` (All absent / All present / Smart).

**Sessions** → Records of attendance taken for an Event on a specific date. Stores a list of `SessionRecord`s (member ID + present/absent status) plus `excludedMemberIds` (members not present at this session). Sessions are immutable after save—edits happen via the repository's replace logic.

**Soft Deletes** → Families, Events, and Sessions have `deletedAt` timestamps. A weekly maintenance job prunes records older than 90 days. Restore is supported via a backup system.

### Persistence & Sync

- **Local JSON files**: `families.json`, `events.json`, `sessions.json` under app documents directory
- **Backup recovery**: If main file is corrupted, `.bak` file is automatically restored
- **Google Drive Sync**: Manual or automatic backup of all JSON files. On merge, pulls new events/sessions from Drive and resolves conflicts
- **Sheets Export**: Sessions can be exported as a detailed table to Google Sheets for analytics/reporting

### Design System: Convocation

The app uses the **Convocation** editorial design language—a serif/sans pairing (Fraunces display + Geist body), postcard-style stamps, tabular numerals, and a calm, considered aesthetic. Key primitives:

- `ConvCard` / `ConvCardSoft` — rounded surfaces (24px / 22px)
- `ConvAvatar` — letter avatar with tone (present/absent/neutral)
- `ConvStamp` — rotated PRESENT/ABSENT stamp
- `ConvSegmented` — two-button control with capsule active state
- `ConvDayChip` — S/M/T/W/T/F/S indicator
- `ConvStatChip` — Present/Absent/Total stat tile

See [DESIGN_SPEC.md](/DESIGN_SPEC.md) in the repo root for full palette, typography, and component reference.

## Key Workflows

### Attendance Taking (Hub → Attendance Flow)

1. Hub shows "Up Next" hero card (today's first unmarked event) + "Also today" / "This week" rows
2. Tap "Start" → AttendanceFlowPage chooses entry mode based on `defaultAttendanceStartMode`
   - **All absent** → Swipe Deck (fast: mark each member 1x, defaults present → absent)
   - **All present / Smart** → Roster List (slower: see all, toggle individually)
3. Deck/List: mark members, undo with history stack, add guest, optionally exclude members
4. Confirm session, choose save (→ session summary, editable) or abandon
5. Summary shows present/absent stats, Regulars (80%+ of last 8 sessions), Trends, and member list with edit/undo

### Smart Defaults

When starting attendance with "Smart" mode or via "Mark Everyone" sheet, members are pre-marked based on last 8 sessions:
- ≥80% present → mark present
- ≤20% present → mark absent
- Between 20–80% → leave untouched

Preseed-marked members are skipped during swipe (fast path) but visible in list mode with a "System (Preseed - Smart)" label.

### Event Management

1. Hub FAB → Add Event Page
2. Fill title, time, frequency (one-time / weekly / bi-weekly / monthly)
3. Select members (or start with none = "all members" by convention)
4. On first attendance for that event, pick roster grouping (By Status / By Family) — saved to event
5. On subsequent markings, roster grouping is inherited

### Member & Family Organization

- Members start in auto-singleton families (one member per family)
- Family Management screens (via Settings) allow:
  - Assign solo members to real families
  - Merge duplicates (same person in multiple families)
  - Delete families (unassigns all members back to singletons)
- Prevent duplicate entries during Add Member (check by name, allow anyway if intentional)

### Insights (Regulars & Trends)

Both reachable from Session Summary:

**Regulars** — Members at ≥80% attendance over the last 8 sessions. Shows:
- Hero card (most consistent member + mini attendance ribbon)
- Ranked list with per-member % + ribbon
- Count tile (n regulars / total members + avg %)

**Trends** — Present-rate trend + session list over a selectable window (12 weeks / 6 months / year). Shows:
- Average attendance % (large editorial numeral)
- Delta vs. prior window ("↑ up from X%")
- Bar chart with dashed average line
- Best / Lowest / Average stat tiles
- Recent session rows (date, weekday, time, present/absent counts, %)

## Testing & Quality

**Coverage threshold: 95%+** (enforced by `dart run tool/check_coverage.dart` on CI)

- **Unit tests** — Pure Dart functions, repositories, domain logic in `test/`
- **Widget tests** — Individual pages and components with `MockTail` mocks
- **Integration tests** — Full app E2E scenarios in `integration_test/`
  - Robot pattern: fluent test helpers (`HubRobot`, `EventRobot`, `AttendanceRobot`, `SettingsRobot`, `MembersRobot`)
  - Scenarios: onboarding, attendance workflows, sync, data integrity, large events, reporting

Key test files:
- `test/widget_test.dart` — Comprehensive page & component coverage
- `integration_test/data_integrity_test.dart` — Member lifecycle, duplicates, cleanup
- `integration_test/quick_marking_entry_test.dart` — Deck/List entry modes, preseeding
- `integration_test/cloud_sync_integration_test.dart` — Drive backup/restore
- `integration_test/reporting_and_export_test.dart` — Sheets export

## Development

### Prerequisites

- Flutter SDK (3.5.0+)
- Dart 3.5.0+
- `.env` file with Google OAuth Client IDs and Firebase keys (see `.env.example`)
- Google Drive API enabled in Google Cloud Console (if using sync)

### Building & Running

```bash
# Static analysis
flutter analyze

# Unit + widget tests with coverage
flutter test --coverage
dart run tool/check_coverage.dart

# Integration tests (requires device/emulator)
flutter drive --target integration_test/app_test.dart

# Run app
flutter run
```

### Common Changes

**Adding a new feature** → Create a new folder under `lib/features/<name>/` with `data/`, `domain/`, `presentation/` subfolders following the feature-sliced pattern. Wire dependencies in `main.dart`.

**Updating the design system** → Edit `lib/core/design/app_colors.dart`, `app_typography.dart`, or `app_theme.dart`. Sync with `DESIGN_SPEC.md`.

**Fixing data persistence** → Check `lib/data/local_session_repository.dart`, `lib/features/attendance/data/attendance_repository.dart`, or `lib/features/hub/data/local_event_repository.dart`. All repos support `.bak` recovery.

**Modifying sync** → See `lib/features/settings/data/drive_service.dart` and `lib/features/settings/data/google_sheets_service.dart`. Sync is manual by default; foreground automatic sync and background periodic sync (`lib/features/settings/data/background_sync_service.dart`, via `workmanager`) are both user-configurable options. See [Background Auto-Sync](/openwiki/integrations.md#background-auto-sync).

## Git History & Context

Recent major changes (last 20 commits):

- **#128** Test coverage elevated to 95%+ (added `google_sign_in_service_test.dart`, expanded domain/repository coverage)
- **#126** Redesigned Manage Backup Data Page ("Storage inspector") with bulk-cleanup, record type filters, detail drawers
- **#127** PR-Agent workflow updated to use Gemini 2.5 Flash
- **#125** Version History page redesigned (timeline snapshots, force-sync buttons integrated)
- **#124** iOS Swift PM dependencies upgraded (`AppAuth-iOS` 2.1.0, `GoogleSignIn-iOS` 9.2.0)
- **#123** Database corruption recovery (`.bak` restore), Drive sync file-rename conflict fix, Sheets export resilience
- **#122** New-Event Roster member picker (tap to open MembersPage as non-persisting selector)
- **#121** Onboarding redesign (Convocation system, final "07 · Onboarding" design conformance)
- **#120** Insights: 80% Regulars threshold, tappable Trends rows, absent-count fix
- **#119** Insights rebuild (Regulars & Trends to "05 Insights" design)

See [CHANGELOG.md](/CHANGELOG.md) for the full history of changes since v1.0.

## Contributing & Code Style

- **Feature-sliced architecture** — Keep concerns separated (data, domain, presentation)
- **Tests first** — Aim for 95%+ coverage; PRs that drop coverage are blocked
- **Design consistency** — Use Convocation primitives (`ConvCard`, `ConvAvatar`, etc) and design tokens from `app_theme.dart`
- **Error handling** — Log failures with `AppLogger` and show user-friendly error messages
- **Git commits** — Reference issues/PRs in commit messages; `CHANGELOG.md` is kept up-to-date

## Backlog

- **Offline-first conflict resolution** (PR #128) — Current Drive sync is pull-only; future work for true offline-first merging
- **Biometric unlock on Cold Start** — App Lock exists but may need refinement on some platforms
- **Sheets formula-driven reporting** — Export is basic table-only; advanced calculated columns not yet supported
- **Family photo attachments** — Design system supports it; data model doesn't yet
- **Historical session editing** — Sessions are immutable after save; full edit would require schema versioning

---

## Pages in This Wiki

- **[Architecture Overview](/openwiki/architecture.md)** — Feature-sliced structure, data models, service graph
- **[Features & Workflows](/openwiki/features.md)** — Attendance, events, member management, insights, settings
- **[Testing & Quality](/openwiki/testing.md)** — Unit/widget/integration tests, coverage, robot framework, CI/CD
- **[Integrations](/openwiki/integrations.md)** — Google Drive, Sheets, OAuth, local backup
- **[Operations & Runbooks](/openwiki/operations.md)** — Build, debug, deploy, common issues, performance notes
- **[Design System](/openwiki/design.md)** — Convocation palette, typography, components, motion

**Last updated**: See [.last-update.json](/openwiki/.last-update.json) for metadata on the most recent documentation refresh.
