# Changelog

All notable changes to this project will be documented in this file. This changelog tracks code changes at the merge/PR level rather than project releases, providing a lightweight history to help prevent regressions.

---

## [Unreleased]

- **Smart Preseeds Skipping & Deck Undo Stack**: Modified the Attendance Deck page to respect and skip members pre-marked by "Smart defaults (from past 8 sessions)" (recorded under a distinct `System (Preseed - Smart)` actor name). Implemented an O(1) set-based caching mechanism to eliminate UI-thread lookups overhead, and introduced a list-based `_history` index stack to replace standard index-decrementing, ensuring robust and correct Undo navigation. Added comprehensive widget testing.
- **Changelog & Agent Workflows**: Established the `CHANGELOG.md` to track git merges/commits, updated instruction systems (`CLAUDE.md`, `GEMINI.md`) to require pre-change context checking and post-change updates, and cleaned up redundant instruction files (`AGENTS.md`).
- **Local-Only Agent Files**: Ignored `CLAUDE.md` and `GEMINI.md` in `.gitignore` and untracked them from git repository to ensure agent instruction files remain local-only.

## Recent Changes

### Family Management Overhaul (May 2026)
- **PR #97**: Improved Family Management by adding dedicated Assign Solo Members and Resolve Duplicates screen workflows.
- **PR #96**: Enhanced Family Management workflows, simplified the screen layout, and added descriptive alert banners.
- **PR #95**: Fixed empty auto-singleton duplicate records and improved detection in the family suggestion engine.
- **PR #90**: Successfully wired previously orphaned family management screens into the Settings navigation hierarchy.

### Convocation System Redesign & Overhaul (May 2026)
- **PR #89 / #81**: Redesigned the Event Members Page with the modern Convocation design system.
- **PR #88 / #80**: Rebuilt the attendance Swipe Deck using smooth gestures and the updated styling.
- **PR #87 / #82**: Reconstructed the Add Event Page to offer structured recurrences and clean card-based options.
- **PR #86**: Rewrote the Attendance Roster list view and introduced the unified `MarkEveryoneSheet`.
- **PR #78**: Streamlined remaining pages and secondary UI flows for full Convocation styling alignment.
- **PR #77**: Replaced legacy visualization widgets with the custom Regulars and Trends screen designs.

### Large-Event Attendance Polish (May 2026)
- **PR #75**: Polished large-event attendance workflows, adding bulk mark-all undo support, smart family member edits, and history-aware default choices.
- **PR #74**: Introduced Event List Mode, bulk defaults, and family grouping options to easily handle events with large attendance rosters.

### CI/CD, Build System & Infrastructure (April – May 2026)
- **PR #85**: Resolved Swift Package Manager and Kotlin Gradle Plugin compatibility warnings on newer platforms.
- **PR #76**: Upgraded Gradle to v8.14 and migrated the Android build environment to use built-in Kotlin.
- **PR #73**: Configured strict incremental unit and widget testing, raising test coverage gate threshold above 95%.
- **PR #70**: Expanded code coverage guidelines for incremental coverage testing on theme models and report filters.
- **PR #69**: Increased testing coverage specifically for Hub UI elements.
- **PR #68**: Boosted unit tests for settings configurations and report exports.
- **PR #67**: Added comprehensive unit test coverage for Google API adapters.
- **PR #66**: Increased testing coverage for family records and Google Drive backup workflows.
- **PR #65**: Implemented code coverage threshold guards to block PRs that drop overall test coverage.
- **PR #59**: Added extensive edge-case tests for automatic local backup routines and session scheduling logic.
- **PR #58**: Stubbed missing `firebase_options.dart` files in the GitHub Actions robo-test CI jobs to avoid compilation errors on clean environments.
- **PR #57**: Configured CI environment to seed gitignored `.env` variables in build environments.

### Feature Additions & Enhancements (April 2026)
- **PR #56**: Added the "Take Attendance" quick launcher shortcut on mobile home screens.
- **PR #55**: Introduced dynamic, biometric/device-credential authentication to securely gate application entry (App Lock).
- **PR #54**: Relocated Crashlytics error handlers to trigger earlier in the startup phase and resolved a black/white startup screen issue on iOS by ensuring plugin registration runs synchronously in `AppDelegate`.
- **PR #53**: Optimized memory allocations by rendering the `LabelAssignments.hasLabel` helper check completely allocation-free.
- **PR #51**: Migrated `google_sign_in` to v7 and modernised extension adapters to v3.
- **PR #50**: Cleaned up stale tests, resolved security vulnerabilities, and purged technical debt from repositories.
- **PR #47**: Unified session roster parsing and deduplication behaviors into a single shared helper class.
- **PR #46**: Patched a fatal crash in the integrity check library and resolved a null-pointer exception during initial silent Google Sign-In.
- **PR #44**: Optimized duplicate file trashing processes in the remote `DriveService` backend.
- **PR #43**: Cached sorted active sessions locally to optimize database retrieval and prevent flickering.
