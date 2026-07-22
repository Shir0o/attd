---
type: Integration Guide
title: "Integrations: Google Drive, Sheets, and OAuth"
description: Explains how Attendance Tracker integrates with Google Drive, Sheets, and OAuth for data sync, backup/restore, and authentication.
---

# Integrations: Google Drive, Sheets, and OAuth

## Google OAuth Flow

### Setup & Configuration

**Files:**
- `lib/features/auth/config/google_oauth_config.dart` — Client ID config
- `lib/features/auth/data/google_sign_in_service.dart` — Sign-In wrapper
- `.env` (gitignored) — Runtime OAuth credentials

**Credentials needed:**

1. **Web Server Client ID** — For Drive/Sheets API server-side auth
2. **iOS Client ID** — For Apple platform
3. **Android Client ID** — For Android platform
4. **Firebase Config** — `google-services.json` (Android) / `GoogleService-Info.plist` (iOS)

**Setup steps:**

1. Create a Google Cloud Project
2. Enable Drive API and Sheets API
3. Create OAuth 2.0 credentials:
   - Web application (for server/backend)
   - iOS app (for native Auth0)
   - Android app (for native Auth0)
4. Download credentials and populate `.env` file (copy from `.env.example`)
5. Enable Drive API in Google Cloud Console (required for sync)

**Environment variables:**

```
# .env (gitignored, never commit)
GOOGLE_OAUTH_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
GOOGLE_OAUTH_WEB_CLIENT_SECRET=xxx
GOOGLE_OAUTH_IOS_CLIENT_ID=xxx.apps.googleusercontent.com
GOOGLE_OAUTH_ANDROID_CLIENT_ID=xxx.apps.googleusercontent.com
```

### Sign-In Flow

**File:** `lib/features/auth/presentation/auth_page.dart`

**Google Sign-In v7 API:**

```dart
// Initialize (in main.dart)
await GoogleSignIn.instance.initialize(
  serverClientId: GoogleOAuthConfig.webServerClientId,
);

// Sign in
final account = await GoogleSignIn.instance.signIn();

// Get authorized client
final authClient = await account?.authentication.client;

// Build Drive/Sheets API from authorized client
final driveApi = drive.DriveApi(authClient);
```

**Key points:**

- **v7 API** — Replaces v6 constructor with `GoogleSignIn.instance.initialize(...)`
- **Server Client ID** — Passed to `initialize()` for Drive/Sheets scope access
- **Token refresh** — Automatic; handled by `google_sign_in` plugin
- **Logout** — `GoogleSignIn.instance.signOut()`

### Scope Management

**Scopes:**

- `drive.DriveApi.driveFileScope` — Most privacy-preserving scope for Drive app-managed files
- `https://www.googleapis.com/auth/spreadsheets` — Sheets API (read/write)

**Implementation:**

```dart
// In DriveService
static const List<String> _driveScopes = <String>[
  drive.DriveApi.driveFileScope
];
```

**Best practices:**

- Request minimal scopes (most restrictive that work)
- `driveFileScope` prevents app from seeing user's entire Drive
- Scopes are immutable once set in OAuth config (no runtime changes)

## Google Drive Sync

### Overview

**File:** `lib/features/settings/data/drive_service.dart`

Backup and restore attendance data to user's Google Drive. Manual or automatic.

**Architecture:**

```
LocalJsonAttendanceRepository (families.json)
LocalJsonSessionRepository (sessions.json)
LocalJsonEventRepository (events.json)
        ↓ (read all)
    DriveService
        ↓ (upload/download)
    Google Drive ("Attendance Tracker Data" folder)
        ↓ (sub-folder: "Backups")
    Timestamped backup zip files
```

### Backup Workflow

**Trigger:** User taps "Sync now" in Settings.

**Steps:**

1. Authenticate (sign in if needed)
2. Find or create "Attendance Tracker Data" app folder in Drive
3. Read all local JSON files (families, sessions, events)
4. Create timestamped zip archive with all files
5. Upload zip to Drive
6. Delete old backups (keep last 5)
7. Notify UI: "Synced at 2:34 PM"

**Code example:**

```dart
Future<void> syncToCloud() async {
  await _ensureAuthenticated();
  
  final families = await attendanceRepository.fetchFamilies();
  final sessions = await sessionRepository.fetchAllSessions();
  final events = await eventRepository.fetchAllEvents();
  
  final archive = Archive();
  archive.addFile(ArchiveFile('families.json', ...));
  archive.addFile(ArchiveFile('sessions.json', ...));
  archive.addFile(ArchiveFile('events.json', ...));
  
  await _uploadArchive(archive);
  _notifySync();
}
```

### Restore Workflow

**Trigger:** User selects a backup version in Cloud Backup page.

**Options:**

1. **Overwrite local** — Pull latest from Drive (destructive: loses local-only changes)
2. **Overwrite cloud** — Push local state to Drive (destructive: loses cloud-only changes)

**Steps (Overwrite local):**

1. Find backup file in Drive
2. Download zip archive
3. Extract families.json, sessions.json, events.json
4. Replace local files
5. Reload UI with new data
6. Show confirmation: "Restored from X date"

**Warning:**

> "This will replace your local data with the version from X date. Your current local changes will be lost."

### Merge & Conflict Resolution

**Current behavior:** Pull-only merge

**Algorithm:**

1. Download all remote sessions/events since last sync
2. For each remote item:
   - If ID exists locally → Skip (local version wins)
   - If ID new → Add (pull remote version)
3. For members/families → Similar logic (prevent duplicates by ID)

**Limitation:**

No true offline-first conflict resolution yet. If user makes conflicting changes locally and on Drive, local wins (conservative approach).

**Future work:** True merge with timestamp-based resolution (PR #128 backlog).

### Error Handling

**Recoverable errors:**

- Network timeouts → Retry with exponential backoff
- Corrupted archive → Log error, suggest manual restore
- Missing Drive folder → Create new one

**Fatal errors:**

- User cancelled auth → Show "Sign in to sync" prompt
- Invalid Drive API credentials → Show "Reauthenticate" button

**Implementation:**

```dart
try {
  await syncToCloud();
} on GoogleSignInUserCancelledException {
  // User cancelled sign-in
  showDialog('Please sign in to sync');
} on IOException {
  // Network error
  showSnackBar('Check your internet connection');
} catch (e) {
  AppLogger('DriveService').error('Sync failed', e, stackTrace);
  showSnackBar('Sync failed. Please try again.');
}
```

### Auto Sync (Optional)

**Setting:** Disabled by default. User can opt-in via Settings toggle.

**Behavior:**

- On app foreground → Sync if >24 hours since last sync
- On successful event/session save → Sync after 5 seconds (debounced)

**Implementation:**

```dart
if (_isDriveSyncEnabled) {
  final lastSync = _lastSyncTime ?? DateTime(2000);
  if (DateTime.now().difference(lastSync) > Duration(hours: 24)) {
    syncToCloud();
  }
}
```

### Background Auto-Sync

**File:** `lib/features/settings/data/background_sync_service.dart`

Unlike the foreground "Auto Sync" above (which fires on app resume/save), Background Auto-Sync runs even when the app is not open, using the [`workmanager`](https://pub.dev/packages/workmanager) plugin to schedule OS-level periodic work (Android `WorkManager` / iOS `BGTaskScheduler`).

**Behavior:**

- Registered from `main.dart` on startup if Drive sync and background sync are both enabled in `SharedPreferences`
- Runs every 12 hours via `BackgroundSyncService.registerPeriodicSync()`, with an optional `wifiOnly` constraint (`NetworkType.unmetered` vs `NetworkType.connected`)
- `callbackDispatcher()` is the `@pragma('vm:entry-point')` entry that Workmanager invokes in a background isolate; it delegates to `executeBackgroundTask()` → `performBackgroundSync()`
- `performBackgroundSync()` re-initializes `SharedPreferences` and a fresh `DriveService`, skips the sync if Drive sync is disabled or the user isn't signed in, otherwise calls `driveService.syncFiles(actionTitle: 'Background Auto-Sync', tags: ['Auto-Sync'])`
- Last run outcome is persisted via `DriveService.lastBackgroundSyncTimeKey` / `lastBackgroundSyncStatusKey` and surfaced in the Settings page's "Background Auto-Sync" row (see [Settings & Configuration](/openwiki/features.md))

**Settings toggles** (`DriveService`):
- `backgroundSyncEnabledKey` — defaults to `true`; toggling calls `BackgroundSyncService.registerPeriodicSync()` or `.cancelSync()`
- `backgroundSyncWifiOnlyKey` — defaults to `true`; re-registers the periodic task with the new network constraint when changed

**Testing:** `test/features/settings/data/background_sync_service_test.dart` covers initialization, registration/cancellation, sync-skip conditions (disabled prefs, not signed in), and error handling. `DriveService` background-sync preference plumbing is covered in `test/features/settings/data/drive_service_test.dart`.

**Watch out for:** Workmanager requires native platform wiring (`AndroidManifest.xml` receiver + iOS `BGTaskScheduler` permitted identifiers) in addition to the Dart API — if background sync silently never fires on a real device, check native registration first, not just the Dart-side toggle state.

## Google Sheets Export

### Overview

**File:** `lib/features/settings/data/google_sheets_service.dart`

Export session attendance data as a detailed table to Google Sheets for analytics and reporting.

**Trigger:** From Settings page or Session Summary page.

### Export Format

**Spreadsheet structure:**

| Column | Type | Example |
| --- | --- | --- |
| Session Date | Date | 2024-05-15 |
| Session Title | Text | Team Meeting |
| Event Name | Text | Weekly Sync |
| Member Name | Text | John Doe |
| Status | Text | Present / Absent / Excused |
| Present Count | Number | 12 |
| Absent Count | Number | 3 |
| Attendance % | Percent | 80% |
| Regulars (80%+) | Yes/No | Yes |
| Notes | Text | Late arrival |

**One row per member per session** (detailed view for pivot analysis).

### Export Process

**Steps:**

1. Authenticate (reuse Drive auth)
2. Create new spreadsheet in user's Drive (or append to existing)
3. Format headers (bold, frozen top row)
4. Fetch all sessions + members
5. Generate rows (session date, title, event, member, status, counts, %)
6. Write to Sheets API
7. Return shareable link

**Code example:**

```dart
Future<String> exportSessions(List<Session> sessions) async {
  await _ensureAuthenticated();
  
  final sheetsApi = sheets.SheetsApi(_authorizedClient);
  final spreadsheet = sheets.Spreadsheet(
    properties: sheets.SpreadsheetProperties(title: 'Attendance Export'),
  );
  
  final created = await sheetsApi.spreadsheets.create(spreadsheet);
  final spreadsheetId = created.spreadsheetId!;
  
  final values = _formatRows(sessions);
  await sheetsApi.spreadsheets.values.append(
    sheets.ValueRange(values: values),
    spreadsheetId,
    'Sheet1',
  );
  
  return 'https://docs.google.com/spreadsheets/d/$spreadsheetId';
}
```

### Error Handling

**Recoverable:**

- Network timeout → Retry
- Invalid sheet → Create new sheet
- Quota exceeded → Show "Try again later"

**Fatal:**

- Auth cancelled → Show "Sign in to export"
- Sheets API disabled → Show "Enable Sheets API in Google Cloud"

**Resilience for corrupted sessions:**

```dart
try {
  final rows = session.records.map((r) => [...]).toList();
} catch (e) {
  AppLogger.warning('Corrupted session, skipping', e);
  // Continue with next session
  rows.add(['ERROR', session.title, 'Corrupted data']);
}
```

## Local Backup Service

### Overview

**File:** `lib/features/settings/data/local_backup_service.dart`

Create/restore zip archives of local JSON files for on-device export or migration.

### Backup to Archive

**Trigger:** User exports from Settings.

**Steps:**

1. Read all local JSON files (families, sessions, events)
2. Create timestamped zip archive (e.g., `attendance_2024-05-15_143000.zip`)
3. Store in app temp directory
4. Return archive URI for share/email

**Code:**

```dart
Future<File> createBackup() async {
  final archive = Archive();
  
  final familiesFile = await _getFile('families.json');
  archive.addFile(ArchiveFile.from(familiesFile));
  
  // ... add other files
  
  final zipBytes = ZipEncoder().encode(archive);
  final backupFile = File('${tempDir.path}/attendance_${timestamp}.zip');
  await backupFile.writeAsBytes(zipBytes);
  
  return backupFile;
}
```

### Restore from Archive

**Trigger:** User imports from backup file (via file picker or upload).

**Steps:**

1. Extract zip contents
2. Validate JSON schema (families, sessions, events)
3. Ask user: "Merge with existing data" or "Replace all"
4. Write to local files
5. Reload repositories

**Merge logic:**

- By-ID: If member/session ID exists, skip (local wins)
- By-timestamp: If sessions have same ID, prefer newer `updatedAt`

## API Error Codes & Recovery

### Drive API Errors

| Error | Cause | Recovery |
| --- | --- | --- |
| 401 Unauthorized | Token expired or revoked | Re-authenticate |
| 403 Forbidden | Insufficient scopes | Show "Reauthenticate" |
| 404 Not Found | File/folder deleted externally | Recreate |
| 429 Too Many Requests | Rate limited | Retry with backoff (max 3 attempts) |
| 500 Server Error | Google's fault | Retry after 5 seconds |

### Sheets API Errors

| Error | Cause | Recovery |
| --- | --- | --- |
| 400 Bad Request | Invalid spreadsheet ID | Show error to user |
| 403 Forbidden | User revoked Sheets permission | Show "Reauthenticate" |
| 404 Not Found | Spreadsheet deleted | Create new one |

### Local File Errors

| Error | Cause | Recovery |
| --- | --- | --- |
| File not found | Database missing | Create empty (first launch) or restore from `.bak` |
| JSON decode error | File corrupted | Restore from `.bak` if available |
| IO error | Disk full or permission denied | Show "Storage full" or "Check permissions" |

## Debugging & Testing

### Mock Google Sign-In

**Test setup:**

```dart
// In test
const googleSignInStub = GoogleSignInStub();
await GoogleSignIn.instance.initialize(
  serverClientId: 'test-client-id',
);

// Sign in returns test account
final account = await GoogleSignIn.instance.signIn();
```

### Mock Drive API

**Using mocktail:**

```dart
class MockDriveApi extends Mock implements drive.DriveApi {}

test('sync creates backup', () async {
  final driveApi = MockDriveApi();
  when(() => driveApi.files.list(...)).thenAnswer((_) async => ...);
  
  final service = DriveService(googleSignIn: mockSignIn);
  await service.syncToCloud();
  
  verify(() => driveApi.files.create(...)).called(1);
});
```

### Test Backup/Restore

```dart
integration_test('backup and restore flow', (tester) async {
  // Create some data
  await hub.createEvent('Test');
  await attendance.markSession(...);
  
  // Backup
  await settings.tapSync();
  await tester.pumpAndSettle();
  expect(find.text('Synced'), findsOneWidget);
  
  // Simulate restore from Drive
  await settings.tapCloudBackup();
  await settings.selectBackupVersion('2 days ago');
  await settings.tapRestoreLocal();
  
  // Verify data restored
  expect(hub.eventCount, isNonZero);
});
```

## Troubleshooting

### "Google Sign-In Failed"

**Checklist:**

1. Is Drive API enabled in Google Cloud Console?
2. Are Client IDs correct in `.env`?
3. Is the signing certificate registered for Android?
4. Is App ID registered for iOS?

**Solution:**

- Re-download `google-services.json` and `GoogleService-Info.plist`
- Update `.env` with correct Client IDs
- Rebuild app: `flutter clean && flutter pub get && flutter run`

### "Sync Timeout"

**Checklist:**

1. Internet connection active?
2. Google Drive API responding?
3. Backup file size (should be <100 MB)?

**Solution:**

- Check internet: `ping google.com`
- Retry with larger timeout: increase `DriveService._syncTimeout`
- If backup is large, enable automatic compression (future feature)

### "Spreadsheet export failed"

**Checklist:**

1. Is Sheets API enabled?
2. Is user authenticated with Sheets scope?
3. Are there corrupted session files?

**Solution:**

- Enable Sheets API in Google Cloud Console
- Re-authenticate (sign out, sign in)
- Run data maintenance: Settings → Manage Data → Cleanup corrupted records

---

## Related Pages

- [Architecture Overview](/openwiki/architecture.md) — Service layer and dependency injection
- [Features & Workflows](/openwiki/features.md) — Settings page and Cloud Backup page UI
- [Operations & Runbooks](/openwiki/operations.md) — Debugging auth and API issues
