# Architecture Overview

## High-Level Design

Attendance Tracker is built with **feature-sliced architecture**, where each feature (Hub, Attendance, Settings, etc.) owns its own data, domain logic, and UI. The app follows clean architecture principles with clear separation between:

1. **Presentation Layer** — Flutter widgets (pages, components)
2. **Domain Layer** — Business logic and domain entities
3. **Data Layer** — Repositories, local JSON persistence, external service integration

```
Presentation (pages, widgets)
    ↓ (uses)
Application (controllers, providers)
    ↓ (uses)
Domain (entities, repositories interfaces)
    ↓ (implements)
Data (local storage, API clients)
```

## Feature-Sliced Structure

```
lib/features/
├── auth/                    # Authentication
│   ├── data/
│   │   ├── google_sign_in_service.dart     # Google Sign-In v7 wrapper
│   │   └── local_auth_repository.dart      # Device credentials (app lock)
│   ├── config/
│   │   └── google_oauth_config.dart        # OAuth client IDs from .env
│   ├── domain/
│   │   ├── entities/
│   │   └── repositories/
│   │       └── auth_repository.dart
│   ├── application/
│   │   └── google_auth_service.dart
│   └── presentation/
│       └── auth_page.dart                  # Sign-in UI
│
├── hub/                     # Dashboard & Event Listing
│   ├── data/
│   │   ├── local_event_repository.dart     # Event JSON persistence
│   │   └── event_repository.dart           # Abstract interface
│   ├── domain/
│   │   └── event.dart                      # Event entity
│   └── presentation/
│       ├── hub_page.dart                   # Dashboard hero + lists
│       ├── hub_attendance_view.dart        # Segmented event display
│       ├── add_event_page.dart             # Event creation
│       └── members_page.dart               # Member picker (for events)
│
├── attendance/              # Quick Marking & Session Summary
│   ├── data/
│   │   └── attendance_repository.dart      # Member/Family JSON persistence
│   ├── models/
│   │   ├── family.dart
│   │   ├── member.dart
│   │   ├── attendance_start_mode.dart      # (All absent / All present / Smart)
│   │   ├── roster_grouping.dart            # (By Status / By Family)
│   │   └── bulk_attendance.dart            # Smart defaults helper
│   ├── utils/
│   │   ├── session_preseed.dart            # Pre-mark logic
│   │   └── session_roster_utils.dart       # Roster deduplication, sorting
│   └── presentation/
│       ├── attendance_flow_page.dart       # Entry point: choose Deck or List
│       ├── attendance_deck_page.dart       # Swipe card UI (fast marking)
│       ├── attendance_roster_list.dart     # List toggle (detailed)
│       ├── mark_everyone_sheet.dart        # Bulk action (All / Smart)
│       ├── swipeable_card.dart             # Reusable swipe component
│       ├── session_summary_page.dart       # Post-attendance review
│       └── grouping_preset_picker.dart     # Choose roster grouping (status vs family)
│
├── sessions/                # Insights (Regulars & Trends)
│   ├── presentation/
│   │   ├── consistent_members_page.dart    # Regulars: ≥80% over last 8 sessions
│   │   └── event_trend_page.dart           # Trends: present-rate + sparkline
│       └── event_history_page.dart         # Session list/timeline
│
├── families/                # Member & Family Management
│   ├── models/
│   │   └── family.dart
│   └── presentation/
│       ├── family_list_page.dart           # Family overview
│       ├── family_details_page.dart        # Edit family
│       ├── add_family_page.dart            # Create family
│       ├── assign_solo_members_page.dart   # Bulk assign unassigned
│       ├── suggest_families_page.dart      # Duplicate detection/merge
│       └── resolve_duplicates_page.dart    # Merge workflow
│
├── reports/                 # CSV/Sheets Export
│   ├── data/
│   │   └── report_export_service.dart      # Sheets export logic
│   └── presentation/
│       └── (export triggered from settings)
│
├── settings/                # Configuration, Backup, Data Management
│   ├── data/
│   │   ├── drive_service.dart              # Google Drive backup/sync
│   │   ├── google_sheets_service.dart      # Sheets export
│   │   └── local_backup_service.dart       # Local backup/restore
│   ├── application/
│   │   ├── theme_controller.dart           # Light/dark mode
│   │   └── app_lock_controller.dart        # Biometric unlock
│   └── presentation/
│       ├── settings_page.dart              # Main settings (Drive, sign-out, etc)
│       ├── cloud_backup_page.dart          # Version history, force sync
│       └── manage_backup_data_page.dart    # Storage inspector (bulk cleanup)
│
├── onboarding/              # 4-Slide Editorial Introduction
│   ├── application/
│   │   └── onboarding_controller.dart
│   └── presentation/
│       ├── onboarding_page.dart
│       └── mock_components.dart            # Art widgets
│
└── reports/                 # Reporting endpoints
    └── presentation/
        └── (integrated into settings)
```

## Core Data Layer

### Session & Session Records

**lib/data/session.dart** — Immutable session entity:

```dart
class Session {
  final String id;
  final String? eventId;           // Link to Event
  final String title;
  final DateTime sessionDate;
  final List<SessionRecord> records;  // attendance[memberId] = present/absent
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;          // "User", "System (Preseed)", etc
  final int currentVersion;        // Schema versioning
  final DateTime? deletedAt;       // Soft delete
  final List<String> excludedMemberIds;  // Members not present
}
```

**lib/data/session_record.dart** — Individual attendance status:

```dart
class SessionRecord {
  final String memberId;
  final String status;  // "present", "absent", "late", "excused"
  // additional fields...
}
```

**lib/data/local_session_repository.dart** — Persistence:

- Stores sessions in `sessions.json` (local app documents)
- Implements soft delete + weekly pruning (>90 days)
- Automatic recovery from `.bak` if main file corrupted
- Conflict resolution during Drive sync

### Member & Family Management

**lib/features/attendance/models/member.dart** — Member entity:

```dart
class Member {
  final String id;
  final String name;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? deletedAt;
}
```

**lib/features/attendance/models/family.dart** — Family grouping:

```dart
class Family {
  final String id;
  final String displayName;
  final bool isAutoSingleton;  // Auto-created for unassigned members
  final List<Member> members;
  final DateTime createdAt;
  final DateTime? deletedAt;
}
```

**lib/features/attendance/data/attendance_repository.dart**:

- Stores families (with member lists) in `families.json`
- Prevents duplicate member names (with user confirmation override)
- Supports family operations: add/delete/merge, move members, detach to singleton

### Event Management

**lib/features/hub/domain/event.dart** — Event entity:

```dart
class Event {
  final String id;
  final String title;
  final TimeOfDay time;
  final String frequency;  // "One-time", "Weekly", "Bi-weekly", "Monthly"
  final DateTime? oneTimeDate;  // For one-time events
  final List<String> repeatingDays;  // For recurring (e.g. ["Monday", "Wednesday"])
  final List<String> memberIds;  // Associated members
  final AttendanceStartMode? defaultAttendanceStartMode;  // Preset for quick start
  final RosterGrouping? rosterGrouping;  // Preset: By Status or By Family
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;  // Soft delete
}
```

**lib/features/hub/data/local_event_repository.dart**:

- Stores events in `events.json`
- Computed helper: `getNextOccurrence(Event)` for scheduling logic
- Soft delete + pruning (same as sessions/families)

## Service & Application Layer

### Dependency Injection (in main.dart)

```dart
final attendanceRepository = LocalJsonAttendanceRepository();
final sessionRepository = LocalJsonSessionRepository();
final eventRepository = LocalJsonEventRepository();

final driveService = DriveService(
  attendanceRepository: attendanceRepository,
  sessionRepository: sessionRepository,
  eventRepository: eventRepository,
);

final localBackupService = LocalBackupService();
final googleAuthService = GoogleSignInAuthService();

// Wired into AttendanceApp
runApp(AttendanceApp(
  repository: attendanceRepository,
  sessionRepository: sessionRepository,
  eventRepository: eventRepository,
  driveService: driveService,
  // ...
));
```

### Key Services

**GoogleSignInAuthService** (`lib/features/auth/data/google_sign_in_service.dart`)
- Wraps Google Sign-In v7 API
- Manages OAuth token refresh
- Provides authorized HTTP client for Drive/Sheets APIs

**DriveService** (`lib/features/settings/data/drive_service.dart`)
- Backup/restore of all JSON files to user's Google Drive
- Manual or automatic sync
- Conflict resolution (pull-merge)
- Change notifications to UI

**GoogleSheetsService** (`lib/features/settings/data/google_sheets_service.dart`)
- Exports session data as detailed table to Sheets
- Integrates with session summary page

**LocalBackupService** (`lib/features/settings/data/local_backup_service.dart`)
- Creates/restores zip archives of local JSON files
- Supports on-device export (e.g., for email or cloud storage)

**DataMaintenanceService** (`lib/core/maintenance/data_maintenance_service.dart`)
- Runs on app startup (checks if >7 days since last run)
- Prunes soft-deleted records older than 90 days
- Prevents database bloat

## UI Architecture

### State Management & Page Structure

- **Minimal state lifting** — Most pages own their UI state (controller + notifier)
- **Streams for data** — Repositories expose `Stream<List<T>>` for real-time updates
- **Service listeners** — Pages subscribe to `ChangeNotifier` services (e.g., `DriveService`, `ThemeController`)
- **Navigation** — Named routes + `MaterialPageRoute` with `NoTransitionsBuilder` (per Convocation design)

### Page Hierarchy

**Onboarding** → **AuthPage** → **HubPage** (dashboard) → feature pages

```
HubPage (dashboard + FAB)
├── AttendanceFlowPage (choose Deck or List mode)
│   ├── AttendanceDeckPage (swipe cards)
│   └── AttendanceRosterList (detailed list)
├── AddEventPage (create/edit event)
├── SessionSummaryPage (review + Regulars/Trends)
│   ├── ConsistentMembersPage (80% Regulars)
│   └── EventTrendPage (sparkline + sessions)
├── FamilyListPage (manage families)
│   ├── FamilyDetailsPage
│   ├── AssignSoloMembersPage
│   └── SuggestFamiliesPage (duplicate merge)
└── SettingsPage
    ├── CloudBackupPage (version history, force sync)
    └── ManageBackupDataPage (storage inspector, bulk cleanup)
```

## Design System Integration

See [DESIGN_SPEC.md](/DESIGN_SPEC.md) for the full Convocation specification.

**Key files:**
- `lib/core/design/app_theme.dart` — Material theme + Convocation extension
- `lib/core/design/app_colors.dart` — Color palette (primary, present, absent, surface ladder, ink ladder)
- `lib/core/design/app_typography.dart` — Fraunces + Geist font pairing and text styles
- `lib/core/design/widgets/` — Reusable Convocation components (ConvCard, ConvAvatar, ConvStamp, etc)

All UI builds on top of these tokens for consistency.

## Error Handling & Logging

**AppLogger** (`lib/core/logging/app_logger.dart`)
- Structured logging with log level filtering
- Integrates with Firebase Crashlytics for fatal errors
- Used throughout to log data mutations and exceptions

**Error Recovery:**
- Database corruption → Auto-restore from `.bak`
- Sync failures → Logged and retried; UI shows status
- Network errors → Graceful degradation; user prompted to retry

## Testing Architecture

See [Testing & Quality](/openwiki/testing.md) for comprehensive coverage.

**Quick summary:**
- **Unit tests** — Pure functions, repositories, domain logic
- **Widget tests** — Individual pages with `MockTail` mocks
- **Integration tests** — Full E2E with robot helpers (fluent API)
- **Coverage enforcement** — 95%+ threshold on CI

## Where to Make Changes

| Area | Where to Change | Key Files |
| --- | --- | --- |
| Add new feature | Create `lib/features/<name>/` with data/domain/presentation | See feature-sliced template above |
| Add new page | Create presentation folder + widget + tests | `lib/features/<feature>/presentation/` |
| Update data model | Edit entity `.dart` file, update repository logic, add migration if needed | `lib/data/`, `lib/features/<feature>/data/` |
| Update design system | Edit design tokens, update Convocation components | `lib/core/design/` |
| Fix sync | Edit DriveService or Sheets logic | `lib/features/settings/data/` |
| Add quick action | Update quick actions service + home screen integration | `lib/core/quick_actions/` |
| Improve error handling | Update AppLogger calls, add Firebase integration | `lib/core/logging/` |

---

**Related pages:**
- [Features & Workflows](/openwiki/features.md) — Detailed walkthrough of each feature
- [Testing & Quality](/openwiki/testing.md) — Test structure and coverage
- [Integrations](/openwiki/integrations.md) — Drive, Sheets, OAuth
