# Development Guide

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
  --dart-define=GOOGLE_ANDROID_CLIENT_ID=your_android_id.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=your_ios_id.apps.googleusercontent.com \
  --dart-define=GOOGLE_WEB_CLIENT_ID=your_web_id.apps.googleusercontent.com
```

## Testing

### Static Analysis
Always run `flutter analyze` to ensure the codebase remains clean and follows Dart linting rules.

### Unit & Widget Tests
Run the full suite of unit and widget tests located in the `test/` directory.

```bash
flutter test
```

### Integration Tests
Integration tests are located in `integration_test/` and require a running emulator or physical device.

```bash
flutter test integration_test/app_test.dart
```

### Mocks and Helpers
- `test/helpers/mocks.dart`: Contains generated mocks using `mockito` for repositories and services.
- `test/helpers/pump_app.dart`: Provides an extension to `WidgetTester` for pumping a localized and themed version of the app.

## Code Standards
- **Linter**: Follows rules defined in `analysis_options.yaml`.
- **Formatting**: Always run `flutter format .` before committing changes.
- **Documentation**: New features must include updates to the relevant `docs/` files.
- **Testing**: Every bug fix or new feature must be accompanied by a corresponding test.

## CI/CD
The project uses GitHub Actions for continuous integration.
- **Workflow**: `.github/workflows/flutter-tests.yml`.
- **Checks**: Automatically runs `flutter analyze` and `flutter test` on every pull request and push to the main branch.
