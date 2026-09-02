# Project-Specific Rules

<!-- Repo-specific agent instructions. The rollout script never touches this file. -->

<!-- ── Migrated from GEMINI.md ── -->

## Agent Instructions
- Always write or update relevant tests when changing code.
- Run the full test suite after modifications to confirm correctness.
- Ensure static analysis (`flutter analyze`) passes with no errors or warnings.
- Keep test coverage aligned with the code changes; avoid skipping tests without justification.
- All unit and widget tests must pass and coverage thresholds must be met before a PR is considered ready (integration tests run nightly or via the `ci:integration-test` label).
## Sandbox Setup (Flutter CLI)
- Install Flutter in the sandbox: `git clone https://github.com/flutter/flutter.git -b stable ~/.flutter`.
- Add the Flutter binary to your PATH for the session: `export PATH="$HOME/.flutter/bin:$PATH"`.
- Verify the toolchain: `flutter doctor`; install any suggested platform deps if prompted.
- Install project packages from the repo root: `flutter pub get`.
## Running Tests
- **Static Analysis:** `flutter analyze`
- **Unit and Widget Tests:** `flutter test`
- **Integration Tests:** `flutter test integration_test/app_test.dart` (requires a running emulator or device)
- **Store Screenshots (Goldens):** `flutter test --update-goldens test/store_screenshots_test.dart` (generates high-quality screenshots in `metadata/en-US/images/` for Phone, 7" Tablet, and 10" Tablet)
## Architecture Patterns
### Instant Transitions & Skeleton Loaders
-- **Instant Transitions**: The app uses `NoTransitionsBuilder` globally to ensure page switches are immediate. Avoid adding artificial delays or complex animations between main screens.
-- **Skeleton Loaders**: Every new page must implement a "Skeleton" or "Loading" state. This state should:
    - Render immediately upon navigation.
    - Use `_ShimmerBox` or similar components to match the final layout's structure.
    - **Minimum Duration**: Maintain the loading state for a minimum of **800ms** (using `Future.delayed`) to prevent flickering and ensure the transition feels intentional and "fluid."
    - Be replaced by the actual content as soon as initial data (e.g., from `SharedPreferences` or local database) is available and the minimum duration has elapsed.
-- **Implementation**: See `SettingsPage` or `HubAttendanceView` for reference implementations of the skeleton pattern.
## Design Principles
- **Visual Standards**: Strictly adhere to the "Fluid Humanist" design system defined in `DESIGN_SPEC.md`.
- **No-Line Rule**: Avoid 1px solid borders; use tonal background shifts for sectioning.
- **Fluidity**: Prioritize pill-shaped components and smooth transitions.

## 5. Test-Driven Development (TDD)
**Write tests before or alongside code changes to guide design and verify behavior.**
- **Red-Green-Refactor**: Write failing unit or widget tests first that capture the desired behavior or reproduce bugs, implement the minimal implementation to pass, then refactor cleanly.
- **Coverage Guard**: Always write or update relevant tests when adding features or modifying code to maintain project line coverage above the required threshold (95.0%).
- **Verification**: Run unit and widget tests (`flutter test`) and static analysis (`flutter analyze`) to confirm correctness before considering work ready for PR.

## 7. Releasing
For Android release workflow, conventional-commit PR title format, and Play Console upload steps, see [RELEASING.md](RELEASING.md). For the rationale behind the pipeline choices, see [docs/adr/0001-release-automation.md](docs/adr/0001-release-automation.md).
---
