# 0005. Scoped Google Drive Subfolder Sharing for Multi-User Attendance Collaboration

## Context
Users need to collaborate with others to take attendance for a specific subset of events without exposing their entire database (unshared events, private notes, or family structures) and without creating security/2FA friction by sharing a single Google account login. The app is privacy-first, local-first, and lacks a centralized multi-tenant database backend.

## Decision
We use a **Scoped Google Drive Subfolder** model using Google Drive's native permission grants:
1. **Isolated Storage**: For any event designated as a **Shared Event**, the owner's app creates a dedicated subfolder in Google Drive (`Attendance Tracker - Shared Events/<Event-ID>`).
2. **Shared Slice**: Only the event definition, assigned members (name and ID only, omitting sensitive notes), and session attendance marks are written to this folder as a **Shared Slice** (`shared_event.json`, `shared_roster.json`, `shared_sessions.json`).
3. **Collaborator Permissions**: The owner invites a **Share Collaborator** by providing their Google email. The app grants `role: writer` via the Google Drive Permissions API (`driveApi.permissions.create`), triggering Google's standard invite without requiring app backend infrastructure.
4. **Opportunistic & Background Sync**: Collaborators authenticate with their own Google account. The app queries for folders shared with the user, discovers shared events, and syncs marks automatically upon app open, event view, session completion, and periodic background tasks.
5. **Mark-Level Merge**: Marks are attributed with the collaborator's identity (`actor`) and merged into the owner's session history using presence precedence (Present/Late takes priority over Absent) without overwriting unrelated events.

## Consequences
- **Zero Central Backend**: Operates completely within Google Drive without recurring server costs or custodial user accounts.
- **Strict Privacy Isolation**: Collaborators never receive access to unshared events, unrelated members, or family details.
- **Clean Identity & Auditability**: Every mark records the specific collaborator who marked it.

## Collaborator Permissions and Lifecycle
- **Guest Attendance**: Collaborators can record **Guest Marks** for unlisted attendees in a shared session without mutating the owner's master roster or creating unverified member records.
- **Access Management**: The event owner can revoke access per collaborator via `driveApi.permissions.delete` or toggle off event sharing to unshare the entire event subfolder.
- **Client Presentation**: Shared events display seamlessly in the collaborator's Hub marked with a "Shared" pill badge, with event editing and deletion actions disabled.
