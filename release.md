# 1.0.8+9
* Enhanced member management, new make-up session FAB, and critical sync reliability fixes.

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
