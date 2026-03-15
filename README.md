# Attendance Tracker

A Flutter app for taking attendance, checking people in, and reviewing quick stats on sessions.

## Setup Prerequisites

To use Google Drive Sync, you must enable the Google Drive API in the Google Cloud Console for your project:

1.  Visit the [Google Drive API Overview](https://console.developers.google.com/apis/api/drive.googleapis.com/overview)
2.  Select your project.
3.  Click **"Enable"**.

### Build Configuration

This project requires Google OAuth Client IDs to be passed at build time via `--dart-define`.

1.  **Android**: Replace `YOUR_ANDROID_CLIENT_ID` in `android/app/src/main/res/values/strings.xml` with your actual Android Client ID from Google Cloud Console.
2.  **iOS**: Replace `YOUR_IOS_CLIENT_ID` in `ios/Runner/Info.plist` with your actual iOS Client ID from Google Cloud Console.
3.  **Run/Build Command**:
    ```bash
    flutter run \
      --dart-define=GOOGLE_ANDROID_CLIENT_ID=your_android_client_id.apps.googleusercontent.com \
      --dart-define=GOOGLE_IOS_CLIENT_ID=your_ios_client_id.apps.googleusercontent.com \
      --dart-define=GOOGLE_WEB_CLIENT_ID=your_web_client_id.apps.googleusercontent.com
    ```

## Features

- Platform-ready app name and package identifiers
- Home screen with attendance overview, quick actions, and recent sessions
- Placeholder actions wired for future workflows
