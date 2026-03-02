## Agent Instructions

- Always write or update relevant tests when changing code.
- Run the full test suite after modifications to confirm correctness.
- Ensure static analysis (`flutter analyze`) passes with no errors or warnings.
- Keep test coverage aligned with the code changes; avoid skipping tests without justification.
- All tests (unit, widget, and integration) must pass before a PR is considered ready.

## Sandbox Setup (Flutter CLI)

- Install Flutter in the sandbox: `git clone https://github.com/flutter/flutter.git -b stable ~/.flutter`.
- Add the Flutter binary to your PATH for the session: `export PATH="$HOME/.flutter/bin:$PATH"`.
- Verify the toolchain: `flutter doctor`; install any suggested platform deps if prompted.
- Install project packages from the repo root: `flutter pub get`.

## Running Tests

- **Static Analysis:** `flutter analyze`
- **Unit and Widget Tests:** `flutter test`
- **Integration Tests:** `flutter test integration_test/app_test.dart` (requires a running emulator or device)
