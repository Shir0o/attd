# Attendance Tracker

A modern, fast, and privacy-focused Flutter application for tracking attendance, managing member engagement, and syncing data seamlessly with Google Sheets and Drive.

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

This project uses a `.env` file to manage sensitive configuration values like Google OAuth Client IDs and Firebase keys.

1.  **Environment Setup**:
    *   Copy the example environment file: `cp .env.example .env`
    *   Fill in your specific IDs and keys in the `.env` file.
2.  **Android**: The project is configured to automatically read the `.env` file for build settings.
3.  **iOS**: The project is configured to automatically read the `.env` file for build settings.
4.  **Run Command**:
    ```bash
    flutter run
    ```
    The app will automatically pick up the configuration from your `.env` file at runtime.

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

