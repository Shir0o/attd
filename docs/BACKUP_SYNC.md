---
layout: default
title: Backup & Sync System
---

# ☁️ Backup & Sync System

## Architecture Overview

The app uses a **merge-based sync** strategy with Google Drive as the cloud storage backend. All data is stored locally as JSON files and synced bidirectionally with Drive.

```
┌──────────┐     merge      ┌──────────────┐     upload      ┌──────────────┐
│  Local    │◄──────────────►│  DriveService │───────────────►│ Google Drive  │
│  JSON     │                │  (merge engine)│◄───────────────│ (appDataFolder)│
└──────────┘                └──────────────┘    download     └──────────────┘
```
...
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
