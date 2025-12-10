## Agent Instructions

- Always write or update relevant tests when changing code.
- Run the test suite after modifications to confirm correctness.
- Keep test coverage aligned with the code changes; avoid skipping tests without justification.

## Sandbox Setup (Flutter CLI)

- Install Flutter in the sandbox: `git clone https://github.com/flutter/flutter.git -b stable ~/.flutter`.
- Add the Flutter binary to your PATH for the session: `export PATH="$HOME/.flutter/bin:$PATH"`.
- Verify the toolchain: `flutter doctor`; install any suggested platform deps if prompted.
- Install project packages from the repo root: `flutter pub get`.
- Run tests to confirm the setup and PATH: `flutter test`.
