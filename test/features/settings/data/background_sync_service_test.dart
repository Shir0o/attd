import 'package:attendance_tracker/features/settings/data/background_sync_service.dart';
import 'package:attendance_tracker/features/settings/data/drive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

class MockWorkmanager extends Mock implements Workmanager {}

class MockDriveService extends Mock implements DriveService {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockWorkmanager mockWorkmanager;
  late MockDriveService mockDriveService;
  late MockGoogleSignInAccount mockUser;

  setUpAll(() {
    registerFallbackValue(ExistingWorkPolicy.replace);
    registerFallbackValue(Constraints(networkType: NetworkType.connected));
  });


  setUp(() {
    mockWorkmanager = MockWorkmanager();
    mockDriveService = MockDriveService();
    mockUser = MockGoogleSignInAccount();

    SharedPreferences.setMockInitialValues({});
  });

  group('BackgroundSyncService', () {
    test('initialize calls Workmanager.initialize', () async {
      when(
        () => mockWorkmanager.initialize(
          any(),
          isInDebugMode: any(named: 'isInDebugMode'),
        ),
      ).thenAnswer((_) async {});

      final service = BackgroundSyncService(workmanager: mockWorkmanager);
      await service.initialize();

      verify(
        () => mockWorkmanager.initialize(
          any(),
          isInDebugMode: any(named: 'isInDebugMode'),
        ),
      ).called(1);
    });

    test(
      'registerPeriodicSync calls Workmanager.registerPeriodicTask',
      () async {
        when(
          () => mockWorkmanager.registerPeriodicTask(
            any(),
            any(),
            frequency: any(named: 'frequency'),
            constraints: any(named: 'constraints'),
            existingWorkPolicy: any(named: 'existingWorkPolicy'),
          ),
        ).thenAnswer((_) async {});

        final service = BackgroundSyncService(workmanager: mockWorkmanager);
        await service.registerPeriodicSync(wifiOnly: true);

        verify(
          () => mockWorkmanager.registerPeriodicTask(
            backgroundSyncUniqueName,
            backgroundSyncTaskName,
            frequency: const Duration(hours: 12),
            constraints: any(named: 'constraints'),
            existingWorkPolicy: ExistingWorkPolicy.replace,
          ),
        ).called(1);
      },
    );

    test('cancelSync calls Workmanager.cancelByUniqueName', () async {
      when(
        () => mockWorkmanager.cancelByUniqueName(any()),
      ).thenAnswer((_) async {});

      final service = BackgroundSyncService(workmanager: mockWorkmanager);
      await service.cancelSync();

      verify(
        () => mockWorkmanager.cancelByUniqueName(backgroundSyncUniqueName),
      ).called(1);
    });
  });

  group('performBackgroundSync', () {
    test('skips when drive sync is disabled', () async {
      SharedPreferences.setMockInitialValues({'drive_sync_enabled': false});

      final result = await performBackgroundSync(
        driveServiceBuilder: () => mockDriveService,
      );

      expect(result, isTrue);
      verifyNever(() => mockDriveService.init());
    });

    test('skips when background sync preference is disabled', () async {
      SharedPreferences.setMockInitialValues({
        'drive_sync_enabled': true,
        DriveService.backgroundSyncEnabledKey: false,
      });

      final result = await performBackgroundSync(
        driveServiceBuilder: () => mockDriveService,
      );

      expect(result, isTrue);
      verifyNever(() => mockDriveService.init());
    });

    test('records skipped status when user is not signed in', () async {
      SharedPreferences.setMockInitialValues({
        'drive_sync_enabled': true,
        DriveService.backgroundSyncEnabledKey: true,
      });

      when(() => mockDriveService.init()).thenAnswer((_) async {});
      when(() => mockDriveService.currentUser).thenReturn(null);

      final result = await performBackgroundSync(
        driveServiceBuilder: () => mockDriveService,
      );

      expect(result, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(DriveService.lastBackgroundSyncStatusKey),
        contains('Skipped'),
      );
    });

    test(
      'performs sync and records timestamp when user is signed in',
      () async {
        SharedPreferences.setMockInitialValues({
          'drive_sync_enabled': true,
          DriveService.backgroundSyncEnabledKey: true,
        });

        when(() => mockDriveService.init()).thenAnswer((_) async {});
        when(() => mockDriveService.currentUser).thenReturn(mockUser);
        when(
          () => mockDriveService.syncFiles(
            actionTitle: any(named: 'actionTitle'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async {});

        final result = await performBackgroundSync(
          driveServiceBuilder: () => mockDriveService,
        );

        expect(result, isTrue);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(DriveService.lastBackgroundSyncStatusKey),
          equals('Success'),
        );
        expect(
          prefs.getString(DriveService.lastBackgroundSyncTimeKey),
          isNotNull,
        );
      },
    );
  });
}
