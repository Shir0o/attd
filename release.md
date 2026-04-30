# 1.2.4+21
*   **Bug Fixes**:
    *   **Permanent Member Association**: Adding a person from the Session Summary or Speed Swipe page now associates them with the event, so they appear in future sessions and on the event's member list.
    *   **Real Members vs. Visitors**: Typing a brand-new name with "Add as Guest" off now creates a real global member (instead of a phantom record); "Add as Guest" on still records a one-off visitor for that session only.
    *   **Live Roster Updates**: Session Summary now reflects member changes from Manage Members immediately, without re-navigation.
    *   **Speed Swipe Suggestions**: The add-person sheet on the swipe page now suggests from the full member roster, not only members already on the event.

# 1.2.3+20
*   **Stability & Fixes**:
    *   **⚡ Resolved Race Condition**: Fixed a critical race condition when saving sessions with a single member, ensuring data consistency during rapid updates.
*   **Documentation & Branding**:
    *   **Refined Project Documentation**: Extensively updated the project's documentation site with a cleaner, full-width layout using the Cayman theme.
    *   **Privacy & Alignment**: Removed redundant GitHub repository links, license labels, and external buttons to better align with private repository standards.
    *   **Cleanup**: Removed legacy screenshots and updated all internal links and timestamps for accuracy.

# 1.2.2+19
*   **UI & UX**:
    *   **Simplified Attendance Start**: Replaced the "Swipe to Start Attendance" slider with a more direct "START" button on event cards.
    *   **On-Demand Attendance**: The "START" button is now available for any event that hasn't had its attendance taken yet, regardless of whether it is scheduled for today.
    *   **Status Text Refinement**: Simplified the attendance status text from "Taken today" to a cleaner "TAKEN".
    *   **Restored Classic Layout**: Reverted to the side-by-side layout for event cards, with the event time on the left and the status action button on the right for better visual consistency.
*   **Code Quality & Maintenance**:
    *   **Component Cleanup**: Removed the unused `SwipeActionTrack` design component and its associated file to streamline the codebase.
    *   **Test Synchronization**: Updated integration tests and test robots to align with the new "START" button interaction logic.
    *   **Verified Fresh Install State**: Confirmed that the application starts with a clean, empty state without any default or sample events.

# 1.2.1+18
*   **UI & UX**:
    *   **Swipe Actions**: Implemented intuitive swipe-to-edit (right) and swipe-to-remove (left) gestures in the Session Summary page.
    *   Added swipe-to-delete (left) for sessions in the Event History page for quicker session management.
    *   **Layout Refinement**: Resolved `RenderFlex` overflows on the home page by removing the redundant member count display from event cards.
*   **Performance**:
    *   **⚡ Optimized Session Retrieval**: Implemented caching for sorted active sessions, significantly reducing load times when navigating session histories.
    *   **Drive Service Optimization**: Optimized duplicate remote file trashing logic to improve cloud sync reliability and speed.
*   **Integrity & Stability**:
    *   Fixed a fatal crash in the `app_device_integrity` plugin and optimized the startup sequence to prevent ANR (Application Not Responding) errors.
    *   Resolved data integrity issues and various UI layout overflows across the app.
*   **Continuous Integration (CI)**:
    *   **Consolidated Test Suite**: Migrated all integration tests into a single, unified suite for more efficient verification in the CI pipeline.
    *   **Robo Tests**: Enhanced automated testing with `google-services.json` injection and updated Firebase Test Lab configurations to use modern Android devices (API 35).
    *   **Automated Patching**: Implemented automatic CI patching for the `app_device_integrity` plugin to ensure consistent and reliable builds.
*   **Testing & Reliability**:
    *   Mocked **Google Sign-In** in all automated tests to prevent execution hangs and improve test reliability.
    *   Refined integration test scenarios, navigation logic, and timings.
    *   Optimized test speed by disabling skeleton loader delays during automated verification cycles.
*   **Maintenance**:
    *   Upgraded core dependencies and resolved Android manifest merger errors by enforcing modern `androidx.test` versions.

# 1.0.16+17
*   **Privacy & Cleanup**:
    *   **Removed Attendance Analytics**: To further prioritize user privacy and focus on core utility, the internal attendance stats and trend visualization features have been removed.
    *   Cleaned up orphaned analytics code and associated unit tests.
    *   Updated the User Guide and Architecture documentation to reflect the streamlined feature set.
    *   Refined UI icons: Replaced "Analytics" icons with more descriptive "Reporting" and "Summary" icons in the Settings and Export screens.
*   **Maintenance**:
    *   Resolved `flutter analyze` warnings by removing unused local variables and imports across the integration test suite.

# 1.0.15+16
*   **Stability & Feedback**:
    *   Integrated **Firebase Crashlytics** for automated crash reporting and better diagnostic tracking.
    *   Improved the **Email Feedback** mechanism: Implemented manual URL encoding to ensure reliable subject/body pre-filling across different email clients.
    *   Fixed a bug where the email app would fail to launch on **Android 11+ and iOS** due to strict URL scheme restrictions.
*   **Platform Specifics (iOS)**:
    *   Configured **dynamic Google OAuth Client IDs** via environment variables for more secure and flexible authentication management.
*   **Testing**:
    *   Added a **comprehensive integration suite** to verify end-to-end app flows.
    *   Enhanced **test robots** for more robust and maintainable integration testing.

# 1.0.14+15
*   **Hub & Historical Data**:
    *   Enhanced the **Historical Data Alert Dialog**: Now includes detailed session information and improved layout.
    *   Fixed a layout exception that occurred in the alert dialog for some data sets.
    *   Unified **Hub buttons** and implemented **auto-sync on finalize** to ensure cloud data is always up-to-date.
*   **UI & Styling**:
    *   Refined **Member Avatar colors** for neutral consistency across the app.
    *   Updated **Onboarding** with a refactored layout, top progress indicator, and high-fidelity mock components matching the actual app UI.
    *   Standardized **action button sizes** (Undo, Absent, Present) for a more balanced look and feel.
    *   Enhanced **Google Sign-In buttons** and **Fluid Loading Border** styling.
*   **Member Management**:
    *   Improved **Manage Members UI** with intuitive swipe actions and status switches.
    *   Streamlined attendance member management within the cloud sync context.
*   **Testing & Maintenance**:
    *   Aligned **integration tests** with the latest UI changes.
    *   Resolved a session caching issue to ensure more reliable data verification.

# 1.0.13+14
*   **Data Integrity & Maintenance**:
    *   Implemented **DataMaintenanceService**: The app now automatically prunes soft-deleted records older than 90 days every week to keep the local database healthy.
    *   Improved **Backup/Sync reliability**: Added `updatedAt` and `deletedAt` timestamps for conflict resolution and implemented **atomic writes** for local storage.
    *   Introduced **Local Backup Rotation**: The repository now maintains `.bak` files during saves for safe data recovery.
*   **UX & Interaction**:
    *   Implemented **Fluid Humanist UI polish** with high-fidelity skeleton loaders across all main pages.
    *   Enhanced **Session Summary**:
        *   Restored the attendance toggle and dedicated swipes for edit/delete actions.
        *   Added **Swipe Gestures** for the attendance roster.
        *   Enabled adding, selecting, renaming, and removing members directly from the summary.
    *   Added **Safety Warnings**: The app now displays specific linked sessions when editing or deleting members or events to prevent accidental data loss.
*   **Performance**:
    *   Optimized attendance and member lookups using internal Maps and Sets, significantly reducing list processing time.
    *   ⚡ Improved **Analytics resolution** speed with an attendee lookup map.
*   **Testing & Reliability**:
    *   Added **Member Lifecycle & Data Integrity** integration tests.
    *   Fixed UI overflows on the attendance deck for smaller device screens.
    *   Aligned historical attendance counting logic to prevent double-counting across different views.

# 1.0.12+13
*   **Performance & UI Smoothness**:
    *   Implemented **Instant Transitions** globally: All page switches are now immediate, removing artificial animation delays for a snappier feel.
    *   Introduced **System-wide Skeleton Loaders**: Pages now render a structural skeleton immediately while background data loads.
    *   Refactored **Settings Page** with a full skeleton state and instant entry.
*   **Settings & About Page Refactor**:
    *   Simplified the "About" section bottom sheet to focus on core app metadata (name, version, legalese).
    *   Removed redundant **Open Source** declarations and **View Licenses** functionality for a cleaner user experience.
*   **UI Polish**:
    *   Modernized **Cloud Version History** UI with a timeline-based design syntax.
    *   Refined dark theme legibility and unified animation durations.

# 1.0.11+12
*   **Data Integrity & Member Management**:
    *   Implemented **hybrid ID-based session records**, allowing for reliable member renames while maintaining backward compatibility with legacy name-based records.
*   **Reporting & Sheets Integration**:
    *   Updated the **Google Sheets Apps Script boilerplate** to include a "Points" column, enabling more detailed engagement analysis in exported reports.
    *   Fixed a regex mismatch in the Apps Script payload by ensuring consistent spacing for key fields.

# 1.0.10+11
*   **Performance & Sync Optimization**:
    *   ⚡ **Optimized Google Drive synchronization**: Implemented concurrent network operations for sequential sync tasks, significantly reducing wait times.
*   **Security & Environment**:
    *   Enhanced **Google Play Integrity** configuration with environment variable support for Google Cloud Project Number.
    *   Added a fail-safe mechanism to handle missing project configuration gracefully.
*   **Member Management Enhancements**:
    *   **Editing in Event Context**: Renaming members is now possible directly from the event management screen, improving flexibility.
    *   Added **loading states** for member creation to prevent duplicate entries during slow operations.
*   **Event & Session Improvements**:
    *   Fixed a bug where **assigned members were lost** when editing existing events.
    *   Cleaned up the **Session Summary** UI by removing redundant status labels.
*   **Testing & Reliability**:
    *   Resolved integration test hangs by replacing `pumpAndSettle` with timed pumps and disabling animations in test mode.

# 1.0.9+10
*   **New Feature**: **Member Editing** functionality, allowing users to update member names directly from the members page.
*   **UX Improvements**: 
    *   **Auto-trimming** whitespace for event and member names to ensure clean data entry.
    *   Enhanced **Google Drive security**: Updated authentication scope to the more restricted `drive.file` for better user privacy.
*   **Bug Fixes & Maintenance**:
    *   Fixed a race condition in the Session Summary during cloud sync.
    *   Optimized CI workflows and GitHub Actions to reduce build usage and improve verification speed.

# 1.0.8+9
*   **UX & Feature Additions**:
    *   Introduced a **Unified Add Member/Guest sheet** for a more streamlined attendance experience.
    *   Added a **Make-up Session FAB** to the Event History page with smooth Hero animations.
    *   Updated the **Attendance Deck** UI for better visual clarity.

# 1.0.7+8
*   **Performance & Optimization**:
    *   Optimized member search by **caching lowercase names** on Member and Family models, significantly improving responsiveness in large databases.
    *   Streamlined the project by **removing desktop-related platforms** (macOS, Linux, Windows) to focus on a high-quality mobile experience.
*   **Testing & Reliability**:
    *   Reworked integration tests with a **comprehensive Full System Scenario**, ensuring robust verification of end-to-end user workflows.
*   **Data Management & Tools**:
    *   Introduced a **Manage Backup Data** screen in Settings, allowing users to manually clean local database records.
    *   Enhanced the **Google Apps Script boilerplate**:
        *   Migrated to `getDisplayValues()` for consistent key matching with formatted sheet data.
        *   Implemented **Map-based duplicate prevention** and explicit removal support for more reliable cloud synchronization.

# 1.0.6+7
*   **Reliability & Data Integrity**:
    *   Fixed a critical race condition in the **Session Summary**: The app now ensures that only newer session snapshots from the repository can update the local state, preventing stale data from overwriting recent attendance markings during slow saves.
*   **Member Management UX**:
    *   Unified the search and add member functionality into a **single intuitive field**.
    *   Implemented **Duplicate Prevention**: A confirmation dialog now appears if you attempt to add a member with a name that already exists.
    *   Enhanced focus management: The input field now automatically clears and refocused after adding a member, keeping the keyboard open for seamless consecutive entries.
*   **Boilerplate & Developer Experience**:
    *   Fixed compilation errors in the Google Sheets Apps Script boilerplate within the Settings UI.

# 1.0.5+6
*   **Performance & UI Smoothness**:
    *   Implemented non-blocking initialization: App UI now renders immediately while Drive sync and silent sign-in happen in the background.
    *   Added professional **Skeleton Loaders** to the Hub for a more fluid initial loading experience.
    *   Optimized perceived speed by reducing artificial "visual consistency" delays from 800ms/400ms to a snappier 250ms across the app.
*   **Google Drive Sync Persistence**:
    *   Drive sync state now persists across app restarts (re-signs in silently and triggers sync if previously enabled).
    *   Refined Sync UI in Settings with more descriptive "Syncing... this may take a while" status and removed redundant manual sync notes.
*   **Store Listing & Asset Generation**:
    *   Built a comprehensive automated screenshot generation pipeline for Phone, 7" Tablet, and 10" Tablet.
    *   Created professional featured graphics for the Google Play listing with matching background themes, marketing text, and soft shadows.
*   **UI & Reliability Fixes**:
    *   Improved layout on small screens: Moved `AddEventPage` save button to `bottomNavigationBar` and adjusted `AttendanceDeckPage` footer to prevent overflow.
    *   Fixed date normalization bug: One-time events no longer show as "Missed" the day after attendance is taken.
    *   Enhanced integration tests with better timing (`pumpAndSettle`) and explicit widget targeting for high-reliability automation.

# 1.0.4+5
*   **Release Stability**:
    *   Fixed `AppDeviceIntegrity` API mismatch in `DriveService` to align with package version 1.1.0.
    *   Resolved build errors in `GeneratedPluginRegistrant` for Android release.
    *   Successfully verified and produced production-ready release builds for both Android (App Bundle) and iOS.

# 1.0.3+4
*   **Production Readiness**:
    *   Renamed package to `com.attd.tracker` to resolve Play Store naming conflicts.
    *   Purged Firebase/Google secrets and identifiers from codebase and git history.
    *   Integrated Google Play Integrity API to enhance app security and resolve authentication issues.
    *   Enabled R8 code shrinking and resource optimization for Android release builds.
    *   Hosted official Privacy Policy via GitHub Pages at `https://shir0o.github.io/attd/`.
    *   Added synchronization disclaimers to the Settings UI for better user transparency.

# 1.0.2+3
*   **Hub & Events Overhaul**:
    *   Replaced the numerical presence count on event cards with a smarter "Attendance Status" (e.g., "Taken today", "Missed (Feb 23)").
    *   Implemented `getLastSupposedOccurrence` logic to accurately track when an event was last expected based on repeating weekdays.
    *   Improved session matching to prevent duplicate session creation when navigating to an event that already has a recent record.
*   **Data & Membership**:
    *   Introduced event-specific member associations (`memberIds` in `Event`).
    *   Linked sessions explicitly to events via `eventId` for better history tracking.
*   **Bug Fixes & Maintenance**:
    *   Fixed UI sync issues where the Hub wouldn't refresh correctly after updating members or events.
    *   Simplified session date calculation to favor the most recent scheduled weekday.
    *   Updated all unit and golden tests to match the new UI and logic.

# 1.0.1+2
* Removed Firebase dependencies and Firebase options configuration.
* Removed AI code and `google_generative_ai` dependencies.
* Refactored static dummy seed data from repositories.
* Created Google Drive automatic backup configuration using standard key.properties.
