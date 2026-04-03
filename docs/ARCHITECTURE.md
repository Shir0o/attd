# Architecture Documentation

## Overview
This application follows a **Feature-Sliced Architecture** (FSA) pattern, tailored for Flutter. The goal is to keep the codebase modular, testable, and maintainable by grouping related logic, models, and UI components into cohesive feature directories.

## Folder Structure

### Core Layer (`lib/core/`)
Contains shared utilities, global design tokens, and infrastructure-level widgets.
- `lib/core/design/`: Defines the "Fluid Humanist" design system (colors, typography, shadows).
- `lib/core/presentation/`: Global UI components and transitions (e.g., `NoTransitionsBuilder`).

### Data Layer (`lib/data/`)
Contains global data models and base repositories that are used across multiple features.
- `lib/data/session.dart`: Core model for an attendance session.
- `lib/data/local_session_repository.dart`: Main persistence logic using `path_provider` and JSON storage.

### Feature Layer (`lib/features/`)
Each directory represents a standalone functional module.
- `attendance/`: Core UI and logic for taking attendance.
- `auth/`: Google OAuth integration and user session management.
- `families/`: Management of member groups (families).
- `hub/`: The main dashboard and event listing.
- `onboarding/`: Initial user setup experience.
- `reports/`: Logic for exporting data to CSV or Google Sheets.
- `sessions/`: History and management of past sessions.
- `settings/`: App configuration and Google Drive sync engine.

## Key Architecture Patterns

### 1. Instant Transitions
To provide a fast, "app-like" feel, we use `NoTransitionsBuilder` in the global `MaterialApp` theme. This removes the standard platform page animations, allowing for immediate navigation between main screens.

### 2. Skeleton Loaders (The Shimmer Pattern)
Every feature page must implement a "Skeleton" state to provide immediate visual feedback during data loading.
- **Requirement**: Maintain the skeleton state for a minimum of **800ms** (using `Future.delayed`) to prevent flickering.
- **Visuals**: Use `_ShimmerBox` or similar components to mimic the final layout's structure.
- **Reference**: See `SettingsPage` or `HubAttendanceView` for implementation details.

### 3. Repository Pattern
Data access is abstracted through repositories. Features often have their own local repositories (e.g., `AttendanceRepository`) which may interact with global data services or local storage.

### 4. Backup & Sync Engine
The application uses a bidirectional, merge-based sync with Google Drive.
- **Location**: `lib/features/settings/data/drive_service.dart`.
- **Strategy**: Last-write-wins with union-merge for legacy data.
- **Atomic Writes**: Uses a tmp-then-rename pattern for local file integrity.
- See `docs/BACKUP_SYNC.md` for a deep dive into the sync logic.

## Design Principles
The UI adheres to the **Fluid Humanist** design system.
- **No-Line Rule**: Sectioning is achieved through background tonal shifts rather than 1px borders.
- **Pill-Shape**: All buttons and interactive tracks are pill-shaped.
- **Tonal Depth**: Hierarchy is defined by luminance changes between surface containers.
- See `DESIGN_SPEC.md` for full design tokens and rules.
