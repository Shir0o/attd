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
