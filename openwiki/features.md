# Features & Workflows

## Attendance Taking (The Core Workflow)

### Entry Point: Hub Dashboard

**File:** `lib/features/hub/presentation/hub_page.dart`

The Hub is the main dashboard. It shows:

1. **"Up Next" Hero Card** — Today's first unmarked event
   - Large serif title, time pill with "TODAY" indicator
   - Expected attendance count (from event memberIds)
   - "Last week" attendance % for comparison
   - "Start" button (blue) or "Taken" pill (if marked)
2. **"Also today" Section** — Remaining same-day events
   - Compact rows with "Marked" status + event title + time
   - Overflow menu (Manage Members, View History, Edit, Delete)
3. **"This week" Section** — Upcoming events (sorted chronologically by next occurrence)
   - Similar compact rows
   - Navigation to event summary or member picker

**Hub Attendance View:** `lib/features/hub/presentation/hub_attendance_view.dart`

Segments events into three categories:

- **Today (unmarked)** — Shows "Up Next" hero + "Also today" group
- **Today (marked)** — Shows "Taken" status (no Start button)
- **Upcoming (future)** — "This week" section

Event sorting:
- Primary: next occurrence date (soonest first)
- Secondary: time of day (earliest first)

### Attendance Entry Flow

**File:** `lib/features/attendance/presentation/attendance_flow_page.dart`

Determines which interface to use based on event's `defaultAttendanceStartMode`:

1. **All absent** → Launch **Swipe Deck** (fast, card-by-card)
2. **All present** → Launch **Roster List** (pre-marked, see all at once)
3. **Smart defaults** → Launch **Roster List** (pre-marked from 80% rule)

User can toggle between Deck and List views after entry.

### Swipe Deck (Fast Marking)

**Files:**
- `lib/features/attendance/presentation/attendance_deck_page.dart`
- `lib/features/attendance/presentation/swipeable_card.dart`

**Interface:**

- Large card showing member name + photo (if available)
- Two-button footer: "Absent" (left, coral), "Present" (right, green)
- Swipe gesture support (swipe left = absent, swipe right = present)
- Smooth fly-off animation on mark, next card flies in
- Undo button (restores last action; no undo stack limit)
- **Guest button** — Type a guest name (one-time member for this session only)
- Next-card peek showing member count progress

**Pre-seeding (Smart Defaults):**

When starting with "Smart" mode or via "Mark Everyone" → **Smart defaults**:

- Calculates each member's attendance % over last 8 sessions
- If ≥80% → Mark present (skip during swipe, but show with "System (Preseed - Smart)" label in Deck)
- If ≤20% → Mark absent (skip during swipe)
- Between 20–80% → Leave untouched

Skipped members are invisible in Deck (fast path) but visible in List mode with a `System (Preseed - Smart)` label. Marked member count is accurate.

**Implementation:**
- `lib/features/attendance/utils/session_preseed.dart` — Pre-mark logic
- `lib/features/attendance/utils/bulk_attendance.dart` — Smart defaults resolver

### Roster List (Detailed View)

**File:** `lib/features/attendance/presentation/attendance_roster_list.dart`

**Interface:**

- Segmented toggle: "By Status" or "By Family" (grouping preset for event)
- Grouped list:
  - By Status: Present | Absent | Later/Excused (if applicable)
  - By Family: Family name header, members with toggle
- Each member row: avatar + name + inline present/absent toggle
- Undo bar (shows last action, tappable to undo)
- **"Mark everyone" button** — Opens bulk action sheet

**"Mark Everyone" Sheet:**

`lib/features/attendance/presentation/mark_everyone_sheet.dart`

Three options:

1. **All present** — Toggle all to present
2. **All absent** — Toggle all to absent
3. **Smart defaults** — Apply 80% rule (see Pre-seeding above)

Shows undo snackbar with count of members resolved.

### Session Confirmation & Summary

**File:** `lib/features/attendance/presentation/session_summary_page.dart`

After marking, user confirms the session:

1. **Review** — Present/Absent hero stats, member list with edit affordance
2. **Options:**
   - **Done** — Save session (immutable; cannot edit)
   - **Cancel** → Discard (if untouched or if session is new; otherwise prompt "Save as is?" or "Discard?")
3. **Post-save UI shows:**
   - Session title + save timestamp ("SAVED · 2:34 PM")
   - Present/Absent hero stats with large numerals
   - **Regulars Card** — "The reliable few" (tappable to full Regulars page)
   - **Trends Card** — Sparkline + rate (tappable to full Trends page)
   - **Member List** — Edit member status inline, view notes, see photo

## Regulars (80% Threshold)

**File:** `lib/features/sessions/presentation/consistent_members_page.dart`

Members who attended ≥80% of the last 8 sessions.

**Computed as:** `(present_count / 8) >= 0.8` (adaptive for short windows)

**Interface:**

- **Hero Card** — "Most consistent" member (highest %), large name, 8-segment attendance ribbon
- **Count Tile** — "X / Y members" (regulars count / total), Avg attendance %
- **"Also reliable" List** — Ranked by %, each row shows:
  - Member name + photo
  - Percentage (large numeral)
  - Hits/window ratio (e.g. "6/8")
  - Mini 8-segment attendance ribbon (green = present, gray = absent)
- **Footer** — "Lives on your device · never shared"

**Reachable from:**
- Session Summary page (card link)
- Trends page (link card removed in latest design)

## Trends (12-Week Sparkline)

**File:** `lib/features/sessions/presentation/event_trend_page.dart`

Present-rate trend + session list over a selectable window.

**Interface:**

1. **Hero Stat** — Large editorial numeral showing average attendance % for selected window
   - Delta chip ("↑ up from X%" or "↓ down from Y%") vs. prior same-length window
2. **Window Selector** — Segmented: "12 weeks" / "6 months" / "Year" (12/26/52 session lookback)
3. **Bar Chart**
   - Y-axis: 0–100% present rate per session
   - X-axis: Session sequence
   - Dashed line: Average % for window
   - Soft card container
4. **Stat Tiles** — Best / Lowest / Average %
5. **Recent Sessions List** — Latest sessions for this event:
   - Row shows: Date · Weekday · Time
   - Present/Absent counts + % (tappable)
   - Chevron affordance (opens that session's summary)
6. **Footer** — "100% local · export to CSV anytime"

**Reachable from:**
- Session Summary page (card link)
- Hub via event row (future)

## Event Management

### Creating an Event

**File:** `lib/features/hub/presentation/add_event_page.dart`

**Form:**

1. **Event Title** — Text input (required)
2. **Time** — Time picker (required)
3. **Frequency** — Radio buttons:
   - One-time (shows date picker)
   - Weekly (shows day selector)
   - Bi-weekly (shows day selector)
   - Monthly (shows day selector)
4. **Members Roster** — Tappable row opens `MembersPage` as non-persisting picker
   - Returns selected members (empty = "all members" by convention)
5. **Save / Cancel**

**First Attendance:**

When starting attendance for a new event, the app prompts:

> "How should we group members during marking?"

- **By Status** (default) — Lists: Present | Absent | Later
- **By Family** — Lists: Family name headers with members

Choice is saved to `Event.rosterGrouping` and inherited for all future sessions.

**Editing Events:**

Opens same form (title, time, frequency, members, grouping). Changes are reflected immediately in Hub.

### Smart "Last Missed" Detection

**File:** `lib/features/hub/domain/event.dart` → `getNextOccurrence(Event)`

For recurring events, the app detects which day is the "last missed" occurrence:

- Looks at sessions for this event over the past 2-3 recurrence periods
- Finds which day(s) lack a session → offers those as "overdue"
- Not enforced (user can create sessions on any day)

## Member & Family Management

### Adding Members

**File:** `lib/features/attendance/presentation/attendance_roster_list.dart` (guest button)

Members can be added:

1. **Permanent members** — Via Family Management (Settings)
2. **Guest (one-time)** — Via "Add guest" button in Deck/List during marking

**Guest flow:**
- Type guest name + tap add
- Member added to this session only
- Not persisted to families.json

### Family Management

**Files:**
- `lib/features/families/presentation/family_list_page.dart`
- `lib/features/families/presentation/family_details_page.dart`
- `lib/features/families/presentation/assign_solo_members_page.dart`
- `lib/features/families/presentation/suggest_families_page.dart`

**Concepts:**

- **Families** — Logical groupings (can be real families, teams, classes, etc)
- **Auto-singletons** — Each member starts alone; can be assigned to a real family
- **Duplicates** — Same member in multiple families (merge via suggest engine)

**Workflows:**

1. **Family List** → See all families + member counts
2. **Family Details** → Edit name, add/remove members, delete family
3. **Add Family** → Create a new family + add members
4. **Assign Solo Members** → Bulk move unassigned members to families
5. **Suggest Duplicates** → Engine detects similar names → user confirms merge

**Duplicate Prevention:**

When adding a member, if a name match exists, app shows:

> "John Doe already exists. Add anyway?"

Allows intentional duplicates (e.g., two people with same name).

### Member Data Backup & Cleanup

**File:** `lib/features/settings/presentation/manage_backup_data_page.dart`

The "Storage Inspector" shows:

- **Record Type Tabs** — All / Events / Sessions / Members / Families / Photos / Attendance
- **Count Badges** — Shows hidden (soft-deleted) and orphan (invalid dependency) records
- **Record Table** — Filterable list of raw JSON objects with:
  - Status badges (hidden / orphan)
  - Detail drawer (expand to see full JSON)
  - ID copy button
  - Delete button (soft-delete; can be undone until pruned)
- **Bulk Cleanup Bar** — Bottom sticky bar with:
  - Counts of flagged records
  - "Clean up all" button
  - Confirmation modal before permanent deletion

## Settings & Configuration

### Main Settings Page

**File:** `lib/features/settings/presentation/settings_page.dart`

**Drive Sync Hero Card:**
- Google account email
- Green "Synced" status dot
- Last sync timestamp
- Side-by-side buttons: "Sign out" / "Sync now"

**Setting Rows (ConvCardSoft):**
1. **Cloud Backup** → Opens Cloud Version History page
2. **Manage Data** → Opens Storage Inspector
3. **Theme** — Light / Dark / System toggle
4. **App Lock** — Biometric unlock on/off
5. **Version** — App version + build number

### Cloud Version History

**File:** `lib/features/settings/presentation/cloud_backup_page.dart`

**Timeline of Backups:**

- Snapshot card per backup showing:
  - Relative timestamp ("2 days ago")
  - Backup size (MB)
  - Device/User label
  - Primary change tag (e.g., "+3 Sessions")

**Force Sync Actions:**
- **Overwrite local** — Pull latest from Drive (destructive: loses local-only changes)
- **Overwrite cloud** — Push local state to Drive (destructive: loses cloud-only changes)

> Note: Force sync should be used rarely and with explicit user intent (confirmation modal).

### Local Backup & Export

**Files:**
- `lib/features/settings/data/local_backup_service.dart`

**Workflows:**

1. **Create local backup** — Zips all JSON files + uploads to Drive/email/cloud storage
2. **Restore from backup** — Unzips and overwrites local state

## Reporting & Export

### Sheets Export

**Files:**
- `lib/features/settings/data/google_sheets_service.dart`
- `test/report_export_service_test.dart`

**Triggered from:**
- Settings page
- Session summary page (export this session's data)

**Exports:**

- Session table with columns:
  - Date, Time, Event, Present, Absent, Present %, Regulars, Trends
  - Member rows (member name, status, notes)

**Error handling:**

- Corrupted session files → Wrapped in try-catch; graceful skip
- Network errors → Logged + user prompted to retry

## Onboarding

**File:** `lib/features/onboarding/presentation/onboarding_page.dart`

**4-Slide Editorial Sequence:**

1. **"Quick take attendance"** — "Quick Marking" art: two-card fan (Jane behind-left, John front-right) + Present/Absent stamps
2. **"Organized by family"** — Family grouping concept
3. **"Local-first. Always yours."** — Privacy/data ownership (no third-party servers)
4. **"Sync to Drive"** — Google Drive backup

**Navigation:**
- "Next" / "Skip" buttons
- Completion → Redirect to Sign-in (AuthPage) or Hub (if already signed in)

---

## Key Domain Concepts

### Attendance Start Modes

**Enum:** `lib/features/attendance/models/attendance_start_mode.dart`

```dart
enum AttendanceStartMode {
  allAbsent,    // Start with all members marked absent (Deck mode)
  allPresent,   // Start with all members marked present (List mode)
  smart,        // Apply 80% rule, start in List mode
}
```

Saved to event as `defaultAttendanceStartMode`. On first attendance for that event, prompts roster grouping choice.

### Roster Grouping Presets

**Enum:** `lib/features/attendance/models/roster_grouping.dart`

```dart
enum RosterGrouping {
  byStatus,     // By Status (Present / Absent / Later)
  byFamily,     // By Family name header
}
```

Saved to event as `rosterGrouping`. Inherited for all future sessions of that event. Can be overridden per-session in the List view.

### Soft Deletes & Pruning

All entities support `deletedAt` timestamp:

- **Soft delete** — Set `deletedAt`, hide from UI, keep in database
- **Pruning** — Weekly maintenance job removes records with `deletedAt` older than 90 days
- **Restoration** — Manual undo via Storage Inspector until pruned

### Session Immutability

Sessions are immutable after save:

- User cannot edit a saved session's attendance list
- Can edit via modal (shown in summary) for individual member status changes
- Full session rewrites not supported in current schema

---

## Where to Make Changes

| Feature | Key Files | Common Changes |
| --- | --- | --- |
| Attendance UI | `attendance_deck_page.dart`, `attendance_roster_list.dart`, `session_summary_page.dart` | Add fields to cards, change stamp animation, adjust undo UX |
| Event Management | `add_event_page.dart`, `local_event_repository.dart` | Add frequency types, change scheduling logic, add event fields |
| Insights | `consistent_members_page.dart`, `event_trend_page.dart` | Adjust 80% threshold, change sparkline window, add stats |
| Family Management | `family_list_page.dart`, `attendance_repository.dart` | Add family fields, change duplicate detection, improve merge UX |
| Export/Sheets | `google_sheets_service.dart`, `report_export_service.dart` | Add columns, change formatting, add formulas |
| Onboarding | `onboarding_page.dart` | Update art, adjust copy, change slide count |

---

**Related pages:**
- [Architecture Overview](/openwiki/architecture.md) — Service and data layer details
- [Testing & Quality](/openwiki/testing.md) — Test patterns for features
- [Integrations](/openwiki/integrations.md) — Google APIs, OAuth flow
