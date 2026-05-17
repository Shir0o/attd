---
layout: default
title: Development Guide
---

# 🛠 Development Guide

## Prerequisites
- **Flutter SDK**: ^3.10.3 (Stable channel recommended)
- **Dart SDK**: ^3.0.0
- **Android Studio / VS Code**: With Flutter/Dart extensions installed.
- **Google Cloud Console**: Project with Google Drive and Sheets APIs enabled for OAuth integration.

## Getting Started

1.  **Clone the repository**:
    ```bash
    git clone <repository-url>
    cd attd
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Google OAuth Setup**:
    - Obtain Android, iOS, and Web Client IDs from the [Google Cloud Console](https://console.cloud.google.com/).
    - Replace placeholders in `android/app/src/main/res/values/strings.xml` and `ios/Runner/Info.plist` with your actual Client IDs.

## Build Configuration
This project uses `--dart-define` to inject Client IDs at build time.

```bash
flutter run \
  --dart-define=GOOGLE_ANDROID_CLIENT_ID=your_android_client_id.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=your_ios_client_id.apps.googleusercontent.com \
  --dart-define=GOOGLE_WEB_CLIENT_ID=your_web_client_id.apps.googleusercontent.com
```

## Testing Strategy

### 1. Static Analysis
Run the linter to ensure code style consistency:
```bash
flutter analyze
```

### 2. Unit & Widget Tests
Execute the primary test suite:
```bash
flutter test --coverage
dart run tool/check_coverage.dart
```

The coverage check reads `coverage/lcov.info`, sums LCOV `LH` and `LF`
line totals, and enforces a 66.9% minimum line coverage baseline. Raise the
threshold in `tool/check_coverage.dart` as follow-up coverage work lands.

### 3. Integration Tests
Run comprehensive end-to-end scenarios (requires a running emulator or physical device):
```bash
flutter test integration_test/app_test.dart
```

### 4. Golden Screenshots
Update the visual regression tests and generate screenshots for marketing:
```bash
flutter test --update-goldens test/store_screenshots_test.dart
```

## CI/CD Pipeline
We use GitHub Actions for automated testing.
- **Flutter Tests**: Runs `analyze` and `test` on every pull request.
- **Robo Tests**: (Optional) Automated UI traversal on Firebase Test Lab.

---
*Refer to [Architecture](./ARCHITECTURE.md) for a deep dive into the code structure.*
