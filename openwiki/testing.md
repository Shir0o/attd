# Testing & Quality

## Coverage Threshold: 95%+

**Enforced by:** `dart run tool/check_coverage.dart`

**CI/CD:** Coverage check runs on every PR. If overall line coverage drops below 95%, the PR is blocked.

```bash
# Run tests with coverage report
flutter test --coverage

# Check against threshold
dart run tool/check_coverage.dart

# Custom threshold
dart run tool/check_coverage.dart --min 94.0

# Custom lcov path
dart run tool/check_coverage.dart --lcov coverage/custom.info --min 95.0
```

**Recent improvements:**
- PR #128 added `google_sign_in_service_test.dart` (closing Google Auth coverage gap)
- Expanded domain entity copy/serialization tests
- Improved local repository exception handling coverage

## Test Structure

### Unit Tests (`test/`)

Pure Dart functions, domain logic, and repository implementations.

**Key test files:**

| File | Coverage | Purpose |
| --- | --- | --- |
| `test/widget_test.dart` | Hub, Attendance, Settings, Onboarding pages | Comprehensive page-level widget tests |
| `test/data/local_session_repository_test.dart` | Session CRUD, soft delete, pruning, `.bak` recovery | Session persistence and recovery |
| `test/features/attendance/data/local_json_attendance_repository_test.dart` | Family CRUD, member ops, duplicates, soft delete | Family/member persistence |
| `test/features/hub/data/local_event_repository_test.dart` | Event CRUD, recurring logic, soft delete | Event persistence |
| `test/features/hub/domain/event_test.dart` | Event entity, copyWith, JSON serialization | Event domain logic |
| `test/features/settings/data/google_sheets_service_test.dart` | Sheets export formatting, error handling | Sheets export logic |
| `test/features/auth/data/google_sign_in_service_test.dart` | OAuth flow, token refresh | Google Sign-In integration |
| `test/features/attendance/utils/session_preseed_test.dart` | 80% rule, smart defaults | Pre-seeding logic |
| `test/features/attendance/utils/bulk_attendance_test.dart` | Bulk mark all, smart defaults resolver | Bulk action logic |
| `test/report_export_service_test.dart` | Session export, CSV formatting | Report generation |

**Test patterns:**

- **Given/When/Then** — Setup, execute, assert
- **Mocks with MockTail** — Mock repositories and services
- **Fixtures** — Reusable test data (sessions, events, members)
- **Error cases** — Missing files, corrupted JSON, network failures

Example:

```dart
test('Family creation and member assignment', () async {
  // Given
  final repo = LocalJsonAttendanceRepository(storagePath: testFile.path);
  
  // When
  final family = await repo.addFamily('The Smiths');
  final updated = await repo.addMember(family.id, Member(
    id: 'john-1',
    name: 'John Smith',
  ));
  
  // Then
  expect(updated.members, hasLength(1));
  expect(updated.members.first.name, 'John Smith');
  expect(updated.isAutoSingleton, false);
});
```

### Widget Tests

Individual pages and components with `MockTail` mocks for repositories and services.

**Key test patterns:**

1. **Setup test app**
   ```dart
   await tester.pumpWidget(createTestApp(...));
   ```

2. **Pump to load**
   ```dart
   await tester.pumpAndSettle();
   ```

3. **Find and tap**
   ```dart
   await tester.tap(find.text('Start'));
   await tester.pumpAndSettle();
   ```

4. **Verify UI state**
   ```dart
   expect(find.text('John Doe'), findsOneWidget);
   ```

**Coverage areas:**

- Page loading and initial state
- User interactions (tap, swipe, input)
- Error states and loading indicators
- Navigation and routing
- Stream updates and real-time data

### Integration Tests (`integration_test/`)

**Robot Pattern:** Fluent test helpers for complex workflows.

**Available robots:**

| Robot | File | Purpose |
| --- | --- | --- |
| `HubRobot` | `robots/hub_robot.dart` | Hub dashboard, event cards, FAB |
| `EventRobot` | `robots/event_robot.dart` | Event creation/editing |
| `AttendanceRobot` | `robots/attendance_robot.dart` | Deck/List marking, undo, guest |
| `MembersRobot` | `robots/members_robot.dart` | Member/family operations |
| `SettingsRobot` | `robots/settings_robot.dart` | Settings, backup, data cleanup |

**Example workflow:**

```dart
final hub = HubRobot(tester);
final event = EventRobot(tester);
final attendance = AttendanceRobot(tester);

// Create event
await hub.tapFab();
await event.enterName('Team Meeting');
await event.save();

// Start attendance
await hub.tapEventCard('Team Meeting');
await attendance.markPresent();  // Swipe deck: mark first member present
await attendance.markAbsent();   // Mark second member absent
await attendance.confirm();      // Save session
```

**Key test scenarios:**

| File | Scenario |
| --- | --- |
| `app_test.dart` | Full app flow: onboarding → auth → hub → attendance → summary |
| `data_integrity_test.dart` | Member lifecycle, duplicates, bulk cleanup |
| `quick_marking_entry_test.dart` | Deck vs List entry modes, pre-seeding, undo |
| `cloud_sync_integration_test.dart` | Drive backup, restore, version history |
| `reporting_and_export_test.dart` | Sheets export, CSV format |
| `advanced_attendance_scenarios_test.dart` | Large events, family grouping, exclusions |
| `resilience_and_failure_test.dart` | Network errors, corrupted files, recovery |
| `fluid_design_and_ux_test.dart` | UI polish, animations, state transitions |
| `auth_lifecycle_test.dart` | Sign-in, sign-out, session resumption |
| `store_listing_screenshots_test.dart` | Generated marketing screenshots |

## Running Tests

### Unit & Widget Tests

```bash
# All tests
flutter test

# Specific file
flutter test test/features/attendance/data/local_json_attendance_repository_test.dart

# With coverage
flutter test --coverage

# With verbose output
flutter test --verbose

# Filter by test name
flutter test -k "Family creation"
```

### Integration Tests

```bash
# All integration tests
flutter drive --target integration_test/app_test.dart

# Specific test
flutter drive --target integration_test/data_integrity_test.dart

# Run on device/emulator (must be connected)
flutter drive --target integration_test/quick_marking_entry_test.dart --device-id <device>
```

### Coverage Report

```bash
# Generate coverage
flutter test --coverage

# View HTML report (requires lcov)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Check threshold
dart run tool/check_coverage.dart
```

## Test Utilities & Fixtures

**File:** `integration_test/utils/test_utils.dart`

- `createTestApp()` — Builds app with test temp directory
- `setupScreenshots()` — Configures golden files
- `seedDatabase()` — Populates test data

**Example:**

```dart
final tempDir = await Directory.systemTemp.createTemp('test_');
final app = await createTestApp(tempDir);

await tester.pumpWidget(app);
await tester.pump(const Duration(milliseconds: 500));

// Now ready for testing
final hub = HubRobot(tester);
```

## Common Test Failures & Fixes

| Error | Cause | Fix |
| --- | --- | --- |
| `MissingPluginException` | Firebase/Google Sign-In not stubbed | Add `.bak` stub in test or use `GoogleSignInStub` |
| `RenderFlex overflow` | Layout widget too small for content | Wrap in integration test `FlutterError.onError` ignore |
| `Timeout on pumpUntilFound` | UI didn't update as expected | Increase pump duration, check async operations |
| `File not found` | Test temp directory not created | Use `Directory.systemTemp.createTemp()` |
| `Coverage below threshold` | New code not tested | Add tests; check `tool/check_coverage.dart` output |

## PR Checklist Before Merging

- [ ] **Coverage maintained** — Run `dart run tool/check_coverage.dart` locally
- [ ] **Tests pass** — `flutter test` + `flutter drive --target integration_test/app_test.dart`
- [ ] **Static analysis passes** — `flutter analyze`
- [ ] **Tests added for new code** — At least one unit or integration test per feature
- [ ] **Error cases covered** — Network failures, invalid input, edge cases
- [ ] **UI tested** — Widget tests verify new pages/components render correctly
- [ ] **CHANGELOG updated** — Document changes in `CHANGELOG.md`

## Debugging Tests

### Print & Log

```dart
print('DEBUG: $variable');
debugPrint('Safe print: $variable');
```

### Tester Helpers

```dart
// Find widgets
print(find.byType(Text).evaluate());

// Pump with delay
await tester.pump(const Duration(seconds: 1));

// Take screenshot
await binding.takeScreenshot('my_screenshot');

// Get widget state
final state = tester.state<MyWidgetState>(find.byType(MyWidget));
```

### Golden Files

```dart
// Update golden images (one-time setup)
flutter test --update-goldens

// Run tests against golden references
flutter test
```

## CI/CD Integration

**GitHub Actions:** `.github/workflows/` — Not in this repo but typical flow:

1. **Lint** — `flutter analyze`
2. **Test** — `flutter test --coverage`
3. **Coverage check** — `dart run tool/check_coverage.dart`
4. **Integration tests** — Robo test on Android/iOS (if configured)
5. **PR Agent** — Automated code review (Gemini 2.5 Flash)

**Local PR validation:**

```bash
# Pre-commit check
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart

# Integration test smoke test
flutter drive --target integration_test/app_test.dart
```

## Adding Tests for New Features

### Step 1: Write Unit Test

```dart
// test/features/new_feature/data/new_feature_test.dart

void main() {
  group('NewFeatureRepository', () {
    test('does something', () async {
      final repo = NewFeatureRepository();
      final result = await repo.doSomething();
      expect(result, isNotNull);
    });
  });
}
```

### Step 2: Write Widget Test

```dart
// test/features/new_feature/presentation/new_feature_page_test.dart

void main() {
  group('NewFeaturePage', () {
    testWidgets('renders content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NewFeaturePage(
            repository: MockNewFeatureRepository(),
          ),
        ),
      );

      expect(find.text('Expected Text'), findsOneWidget);
    });
  });
}
```

### Step 3: Add Integration Test (if needed)

```dart
// integration_test/new_feature_test.dart

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('New Feature E2E', () {
    testWidgets('complete workflow', (tester) async {
      final tempDir = await Directory.systemTemp.createTemp();
      final app = await createTestApp(tempDir);

      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // Test workflow
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(find.text('Success'), findsOneWidget);
    });
  });
}
```

### Step 4: Verify Coverage

```bash
flutter test --coverage
dart run tool/check_coverage.dart
```

If coverage is below 95%, add more tests or increase line hit count.

## Performance & Benchmarks

**Benchmarks:** `test/benchmark_*.dart`

- `benchmark_drive_logic.dart` — Drive sync performance
- `benchmark_session_sort.dart` — Session sorting performance
- `standalone_benchmark.dart` — Standalone benchmark runner

These are not run on CI but are useful for profiling during optimization.

---

## Related Resources

- [CHANGELOG.md](/CHANGELOG.md) — PR-level test coverage changes
- [Architecture Overview](/openwiki/architecture.md) — Service dependencies for mocking
- [Features & Workflows](/openwiki/features.md) — Feature behaviors to test
- [Official Flutter Testing](https://flutter.dev/docs/testing) — Dart/Flutter test docs
