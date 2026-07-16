# Operations & Runbooks

## Local Development Setup

### Prerequisites

- **Flutter SDK** — 3.5.0+ (check with `flutter --version`)
- **Dart SDK** — Included with Flutter, 3.5.0+
- **Xcode** — 15.0+ (for iOS builds)
- **Android Studio** — 2023.2+ (for Android builds)
- **Google Cloud Project** — For OAuth and Drive API

### First-Time Setup

```bash
# 1. Clone and enter directory
git clone <repo-url>
cd attd

# 2. Get dependencies
flutter pub get

# 3. Copy environment file
cp .env.example .env

# 4. Fill in OAuth credentials in .env
# Edit .env and add your Google OAuth Client IDs
# (See Integrations page for setup)

# 5. Build and run
flutter run

# 6. Verify setup
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart
```

### Environment File (.env)

**Location:** `.env` (gitignored, never commit)

**Required variables:**

```
GOOGLE_OAUTH_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
GOOGLE_OAUTH_IOS_CLIENT_ID=xxx.apps.googleusercontent.com
GOOGLE_OAUTH_ANDROID_CLIENT_ID=xxx.apps.googleusercontent.com
```

**How to obtain:**

1. Visit [Google Cloud Console](https://console.cloud.google.com)
2. Create or select your project
3. Enable **Drive API** and **Sheets API**
4. Create OAuth 2.0 credentials (Web, iOS, Android)
5. Copy Client IDs into `.env`

**Test with hardcoded values:**

For local testing without full OAuth setup, you can temporarily use placeholder values. The app will prompt for sign-in when needed.

## Building for Release

### Android Build

```bash
# 1. Update version in pubspec.yaml
# version: 1.3.0+23  (increment build number)

# 2. Build APK
flutter build apk --release

# 3. Build App Bundle (Google Play)
flutter build appbundle --release

# Output: build/app/outputs/flutter-app.apk or app-release.aab
```

**Signing:**

The Android build is configured with a keystore. If not present:

```bash
# Generate keystore (one-time)
keytool -genkey -v -keystore ~/key.jks -keyalias key \
  -keyalg RSA -keysize 2048 -validity 10000

# Update android/local.properties with keystore path
echo "storeFile=~/key.jks" >> android/local.properties
echo "storePassword=<password>" >> android/local.properties
echo "keyAlias=key" >> android/local.properties
echo "keyPassword=<password>" >> android/local.properties
```

### iOS Build

```bash
# 1. Open Xcode
open ios/Runner.xcworkspace

# 2. Update version in Xcode:
# - General tab: Version and Build numbers
# - Or edit ios/Runner.xcodeproj/project.pbxproj

# 3. Build and archive
flutter build ipa --release

# 4. Upload to TestFlight / App Store via Xcode organizer
# Or use:
xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme Runner -configuration Release -archivePath build/ios/archive.xcarchive -archive

xcodebuild -exportArchive -archivePath build/ios/archive.xcarchive \
  -exportOptionsPlist ios/ExportOptions.plist -exportPath build/ios/ipa
```

**Certificates & Provisioning:**

Managed via Apple Developer account. Ensure:

- App ID registered
- Provisioning profile up-to-date
- Signing certificate installed in Keychain

## Running Tests & Coverage

### Unit & Widget Tests

```bash
# Run all tests
flutter test

# Run with coverage report
flutter test --coverage

# Check coverage threshold
dart run tool/check_coverage.dart

# Custom min coverage
dart run tool/check_coverage.dart --min 94.0
```

### Integration Tests

```bash
# Run on connected device/emulator
flutter drive --target integration_test/app_test.dart

# Run specific test
flutter drive --target integration_test/data_integrity_test.dart

# With output
flutter drive --target integration_test/app_test.dart --verbose
```

### Static Analysis

```bash
# Lint and analysis
flutter analyze

# Fix auto-fixable issues
dart fix --apply

# Custom rules (if configured)
dart analyze lib/
```

## Debugging

### Run in Debug Mode

```bash
# Default (debug)
flutter run

# With observer logging
flutter run -v

# On specific device
flutter run -d <device-id>

# List available devices
flutter devices
```

### DevTools

```bash
# Start DevTools standalone
flutter pub global activate devtools
devtools

# Or open from running app:
# In terminal, press 'd' to open DevTools
```

**Features:**

- Inspector (widget tree, properties)
- Profiler (CPU, memory, timeline)
- Debugger (breakpoints, variables)
- Logging (print statements, structured logs)

### Common Debug Scenarios

**Widget not rendering:**

```dart
// Enable debug paint
debugPaintSizeEnabled = true;

// Print widget tree
debugDumpApp();

// Take screenshot for comparison
binding.takeScreenshot('debug_screenshot');
```

**Performance issue:**

```bash
# Profile CPU/memory
flutter run --profile

# Check frame rate
flutter run -v | grep 'fps'

# Use DevTools Profiler tab to find hot spots
```

**Database corruption:**

```dart
// In app code
final file = File('${dir.path}/sessions.json');
print('File exists: ${await file.exists()}');
print('Size: ${(await file.stat()).size} bytes');

// Check backup file
final backup = File('${file.path}.bak');
print('Backup exists: ${await backup.exists()}');
```

## Common Issues & Solutions

### Issue: "Google Sign-In Failed"

**Symptoms:** App crashes or shows error after tapping Sign In

**Checklist:**

1. Is Drive API enabled in Google Cloud Console?
2. Are OAuth Client IDs correct in `.env`?
3. For Android: Is signing certificate SHA-1 registered?
4. For iOS: Is Bundle ID registered in Apple Developer?

**Fix:**

```bash
# 1. Verify .env
cat .env | grep GOOGLE_OAUTH

# 2. Rebuild with correct credentials
flutter clean
flutter pub get
flutter run

# 3. If still failing, try explicit sign out + re-sign-in
# In the app: Settings → Sign out → Start attendance → Sign in
```

### Issue: "Coverage below 95%"

**Symptoms:** CI/CD blocks PR with coverage threshold failure

**Quick fix:**

```bash
# 1. Check current coverage
dart run tool/check_coverage.dart

# 2. Identify uncovered lines
# (look at coverage/lcov.info or HTML report)

# 3. Add tests for those lines
# See Testing & Quality page for patterns

# 4. Re-run
flutter test --coverage
dart run tool/check_coverage.dart

# Should now pass
```

### Issue: "Build failed: Firebase plugin not found"

**Symptoms:** `MissingPluginException` on Android/iOS

**Fix:**

```bash
# 1. Clean and rebuild
flutter clean
flutter pub get

# 2. Ensure Firebase is initialized
# Check main.dart has Firebase.initializeApp()

# 3. Rebuild
flutter run
```

### Issue: "Database file corrupted"

**Symptoms:** App crashes when loading sessions/families/events, shows "Bad JSON" error

**Automatic fix:**

The app auto-detects corrupted `.json` files and restores from `.bak`:

1. Main file (e.g., `sessions.json`) is corrupted
2. App detects empty/invalid content
3. App checks for `sessions.json.bak`
4. If backup exists, copies it to main file
5. App continues normally

**Manual fix:**

```bash
# On device (via adb)
adb shell

# Locate app directory
ls /data/data/com.example.attendance_tracker/files/

# Check backup file size
ls -la sessions.json.bak

# If backup is valid, copy it
cp sessions.json.bak sessions.json

# Exit
exit

# Restart app
```

### Issue: "Sync timeout"

**Symptoms:** "Check your internet connection" after 30 seconds on Sync

**Checklist:**

1. Is device connected to internet?
2. Is Google Drive API responding? (Check status.cloud.google.com)
3. Is backup file too large (>100 MB)?

**Fix:**

```bash
# 1. Check connectivity
ping google.com

# 2. Try sync again (manual retry)
# In app: Settings → Sync now

# 3. If large backup, enable compression (future feature)
# For now, prune old backups via Manage Data page
```

### Issue: "App Lock not working"

**Symptoms:** Biometric auth doesn't appear or skips on startup

**Checklist:**

1. Is biometric enabled in Settings?
2. Does device have fingerprint/face registered?
3. Is local_auth plugin properly initialized?

**Fix:**

```dart
// In settings_page.dart, check AppLockController initialization
final controller = AppLockController(prefs);

// Verify local_auth can access biometrics
final localAuth = LocalAuthentication();
final canAuth = await localAuth.canCheckBiometrics;
print('Biometrics available: $canAuth');

// Test biometric prompt
final authenticated = await localAuth.authenticate(
  localizedReason: 'Unlock Attendance Tracker',
);
print('Auth result: $authenticated');
```

## Performance Optimization

### Memory Usage

**Profile with DevTools:**

```bash
flutter run
# Press 'd' in terminal to open DevTools
# Go to Memory tab → Dart Heap
# Take snapshots and compare
```

**Common optimizations:**

1. **Lazy-load large lists** — Use `ListView.builder` instead of `ListView`
2. **Dispose streams** — Always unsubscribe in `dispose()`
3. **Avoid repeated builds** — Use `const` constructors
4. **Cache parsed data** — Store `_allFamilies` in memory (already done in repos)

### Startup Time

**Measure:**

```bash
flutter run -v | grep 'Launching' | grep 'took'
```

**Optimize:**

1. **Reduce Firebase initialization time** — Move to background if possible
2. **Defer non-critical data** — Don't load all sessions on startup
3. **Use lazy initialization** — Controllers built only when needed

### Database Query Performance

**Benchmark:**

```bash
dart run test/benchmark_session_sort.dart
```

**Typical performance:**

- Load 1000 sessions: <100ms
- Sort by date: <50ms
- Filter by event: <20ms

**If slow:**

1. Check JSON file size (should be <10 MB for normal use)
2. Consider pagination or windowing
3. Profile with DevTools Timeline tab

## Monitoring & Logging

### Structured Logging

**Via AppLogger:**

```dart
import 'core/logging/app_logger.dart';

final _log = AppLogger('MyFeature');

_log.info('Session created: ${session.id}');
_log.warning('Potential duplicate member: ${member.name}');
_log.error('Sync failed', exception, stackTrace);
```

**Log levels:**

- `info` — Normal operations
- `warning` — Unexpected but handled (e.g., duplicate member)
- `error` — Failures logged to Firebase Crashlytics

### Firebase Crashlytics

**Automatic reporting:**

```dart
// In main.dart
FlutterError.onError = (errorDetails) {
  FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
};

PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```

**Manual reporting:**

```dart
try {
  // risky operation
} catch (e, st) {
  FirebaseCrashlytics.instance.recordError(e, st);
  rethrow;
}
```

**View crashes:** [Firebase Console](https://console.firebase.google.com) → Crashlytics tab

## Deployment Checklist

### Before Releasing

- [ ] **Version bumped** in `pubspec.yaml` (e.g., `1.3.0+23`)
- [ ] **CHANGELOG updated** with PR summary and fixes
- [ ] **All tests pass** — `flutter test --coverage && dart run tool/check_coverage.dart`
- [ ] **Static analysis passes** — `flutter analyze`
- [ ] **Screenshots generated** — `flutter drive --target integration_test/store_listing_screenshots_test.dart`
- [ ] **Build tested locally** — `flutter build apk --release` and `flutter build ipa --release`
- [ ] **Integration tests pass** on real device
- [ ] **Code review approved**
- [ ] **Release notes drafted** (for App Store/Play Store)

### Release Steps

**Google Play:**

1. Build App Bundle: `flutter build appbundle --release`
2. Upload to Google Play Console
3. Set version and release notes
4. Submit for review (typically approved in 1-2 hours)

**App Store:**

1. Build IPA: `flutter build ipa --release`
2. Upload via Xcode organizer or transporter
3. Submit for review (typically approved in 24 hours)
4. Schedule release

**GitHub Releases:**

```bash
git tag v1.3.0
git push origin v1.3.0

# Create release on GitHub with changelog
```

## Debugging CI/CD

### GitHub Actions Logs

1. Visit repo → Actions tab
2. Click failing workflow run
3. Expand job logs
4. Search for error keywords (FAIL, ERROR, EXCEPTION)

**Common CI failures:**

| Error | Cause | Fix |
| --- | --- | --- |
| `flutter analyze` fails | Lint rule violation | Run `flutter analyze` locally; fix; commit |
| `flutter test` fails | Unit/widget test failure | Run `flutter test -k 'test name'` locally; debug |
| `check_coverage` fails | Coverage below 95% | Add tests; run locally to verify |
| Build fails | Dependency issue | Run `flutter pub get` locally; check `.flutter-plugins` |

### Local CI Simulation

```bash
# Run full CI pipeline locally
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart
flutter build apk --release
flutter build ipa --release

# If any fail, fix and commit
```

---

## Related Pages

- [Testing & Quality](/openwiki/testing.md) — Detailed test setup and coverage
- [Integrations](/openwiki/integrations.md) — Troubleshooting OAuth, Drive, Sheets
- [Architecture Overview](/openwiki/architecture.md) — Service dependencies and config
