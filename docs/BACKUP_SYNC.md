# Backup & Sync System

## Architecture Overview

The app uses a **merge-based sync** strategy with Google Drive as the cloud storage backend. All data is stored locally as JSON files and synced bidirectionally with Drive.

```
┌──────────┐     merge      ┌──────────────┐     upload      ┌──────────────┐
│  Local    │◄──────────────►│  DriveService │───────────────►│ Google Drive  │
│  JSON     │                │  (merge engine)│◄───────────────│ (appDataFolder)│
└──────────┘                └──────────────┘    download     └──────────────┘
```

### Synced Files

| File | Type | Data |
|------|------|------|
| `sessions.json` | List | Attendance sessions |
| `events.json` | List | Recurring/one-time events |
| `families.json` | List | Family roster with nested members |
| `sessions_history.json` | Map | Version history per session |

### Sync Trigger Points

- **Auto**: On app launch (if sync enabled and signed in)
- **Auto**: When sync is toggled on
- **Manual**: "Sync Now" button in Settings

---

## Conflict Resolution

### Strategy: Last-Write-Wins with Union Merge

When both local and remote have data for the same file, the system:

1. Downloads remote data
2. Merges with local data by ID
3. Writes merged result to both local and remote

### Resolution Rules

| Scenario | Resolution |
|----------|------------|
| Item exists only locally | Added to merged output |
| Item exists only remotely | Added to merged output |
| Same ID, both have `updatedAt` | **Latest `updatedAt` wins** |
| Same ID, no `updatedAt` (legacy families) | Member lists are union-merged |
| Session history versions | Merged by version number; ties broken by `recordedAt` |

### Soft-Delete Propagation

Items have an optional `deletedAt` timestamp. When a member or family is "deleted":

1. `deletedAt` is set to `DateTime.now()` (not physically removed)
2. The item persists in JSON for sync propagation
3. `fetchFamilies()` filters out soft-deleted items before returning to the UI
4. During merge, if the same ID exists on both sides, the one with the newer `updatedAt` wins — so a deletion (which sets both `deletedAt` and `updatedAt`) propagates if it's the most recent change

### Backward Compatibility

Models deserialize `updatedAt` from JSON, defaulting to epoch (`DateTime(0)`) when missing. This means:
- Pre-update data syncs normally
- The first edit after upgrading will give the item a proper `updatedAt`
- Any item with a real `updatedAt` will always win over a legacy epoch value

---

## Data Integrity

### Atomic Writes

Local file writes use a **tmp-then-rename** pattern to prevent corruption if the app crashes mid-write:

```dart
final tmpFile = File('${file.path}.tmp');
await tmpFile.writeAsString(content);
await tmpFile.rename(file.path);
```

### Self-Healing

If remote data is corrupted (invalid JSON, wrong schema type), the sync engine:

1. Detects the corruption via JSON decode + type check
2. Verifies local data is healthy (valid `List` or `Map`)
3. Uploads local data to "heal" the cloud copy

### Integrity Checks

Before merging, both local and remote data are validated:
- `sessions.json`, `events.json`, `families.json` must be `List`
- `sessions_history.json` must be `Map<String, dynamic>`
- Schema mismatches trigger a `FormatException` → falls back to time-based sync

### Duplicate Remote File Cleanup

`_listRemoteFiles()` detects duplicate files with the same name on Drive (can happen from interrupted uploads). It keeps the most recent and trashes older duplicates.

---

## Cloud Backup Snapshots

Separate from live sync, users can create **manual cloud backup snapshots**:

- Stored in a `Backups/` subfolder on Drive as timestamped ZIP files
- Contains all 4 JSON files
- Restore performs a **merge** (not replacement) with current local data
- Snapshots have a maximum count; oldest are pruned automatically

---

## Key Files

| File | Purpose |
|------|---------|
| `lib/features/settings/data/drive_service.dart` | Core sync engine, merge logic, Drive API |
| `lib/features/settings/data/local_backup_service.dart` | Local ZIP backups and CSV export |
| `lib/features/attendance/data/attendance_repository.dart` | Family/member persistence, soft-delete filtering |
| `lib/features/attendance/models/family.dart` | Family model with `updatedAt`/`deletedAt` |
| `lib/features/attendance/models/member.dart` | Member model with `updatedAt`/`deletedAt` |
| `lib/data/session.dart` | Session model with `deletedAt` |
| `lib/features/hub/domain/event.dart` | Event model with `deletedAt` |

---

## Potential Future Improvements

### High Priority

#### 1. Optimistic Concurrency Control (ETags)
Use Google Drive's file revision IDs to detect concurrent edits. Before uploading merged data, check that the revision hasn't changed since download. If it has, re-download, re-merge, and retry. This prevents the race condition where two devices sync simultaneously and one overwrites the other's merge.

#### 2. Soft-Delete Pruning / Tombstone TTL
Soft-deleted items accumulate in JSON files indefinitely. Implement a time-to-live (e.g., 90 days) after which soft-deleted items are physically removed. This keeps file sizes manageable.

#### 3. Device ID in Sync Metadata
Generate a UUID per device (stored in SharedPreferences) and include it in each sync write. This enables debugging multi-device conflicts and tracking which device last wrote each file.

### Medium Priority

#### 4. Incremental Sync / Change Tracking
Track a local change log (which IDs were modified since last sync) instead of downloading and merging the full file every time. Reduces bandwidth and sync time as data grows.

#### 5. Background Sync
Use `workmanager` or similar to perform periodic background syncs even when the app isn't in the foreground. This reduces the chance of large divergences between devices.

#### 6. Conflict Resolution UI
When items have close `updatedAt` values (within a small window), present both versions to the user and let them choose instead of silently picking the latest.

### Low Priority

#### 7. Distributed Locking
Create a `.lock` file on Drive before syncing; other devices wait or abort if the lock is active. Include a staleness timeout (e.g., 5 minutes) so crashed devices don't permanently block sync.

#### 8. End-to-End Encryption
Encrypt JSON data before uploading to Drive. Decrypt on download. Protects user data at rest in the cloud.

#### 9. Sync Progress Reporting
Stream granular progress during sync (e.g., "Merging families... Uploading sessions...") instead of just a spinner. Improves UX for large datasets.

#### 10. Selective Sync
Allow users to choose which data types to sync (e.g., sync sessions but not families). Useful for shared devices or partial sync scenarios.
