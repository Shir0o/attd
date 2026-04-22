---
layout: default
title: Introduction
---

# 🚀 Introduction
A high-level overview of the Attendance Tracker application, its core features, and the mission behind its development.

Attendance Tracker is a modern, fast, and privacy-focused Flutter application designed for tracking attendance, managing member engagement, and syncing data seamlessly with Google Sheets and Drive.

## ✨ Features

- **Hub Dashboard**: Quick overview of all events and recent attendance sessions.
- **Member Management**: Easily add, search, and edit member records with duplicate prevention.
- **Event Tracking**: Support for one-time and recurring events with smart "Last Missed" detection.
- **Google Drive Sync**: Secure, manual, and automatic backups of your attendance data to your personal Google Drive.
- **Sheets Export**: Integration with Google Sheets for advanced reporting and data analysis.
- **Privacy First**: No third-party servers; your data stays in your local storage and your Google account.

## 🚀 Setup Prerequisites

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

## 🛠 Development

### Running Tests
Ensure the project's health by running the test suite:

```bash
# Static Analysis
flutter analyze

# Unit and Widget Tests
flutter test
```

### Folder Structure
- `lib/data/`: Core data models and local repository logic.
- `lib/features/`: Feature-sliced architecture (Attendance, Auth, Hub, Settings, etc.).
- `lib/features/auth/`: Google OAuth configuration and services.
- `integration_test/`: Comprehensive E2E system scenarios.

