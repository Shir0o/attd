import 'package:attendance_tracker/features/settings/data/background_sync_service.dart';
import 'package:attendance_tracker/features/settings/data/drive_service.dart';
import 'package:flutter/services.dart';
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
    registerFallbackValue(ExistingPeriodicWorkPolicy.update);
    registerFallbackValue(Constraints(networkType: NetworkType.connected));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(
        'be.tramckrijte.workmanager/background_channel_work_manager',
      ),
      (methodCall) async => true,
    );
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
        ),
      ).thenAnswer((_) async {});

      final service = BackgroundSyncService(workmanager: mockWorkmanager);
      await service.initialize();

      verify(
        () => mockWorkmanager.initialize(
          any(),
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
            existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
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

    test('returns false and records error when sync throws', () async {
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
      ).thenThrow(Exception('Sync failed Network error'));

      final result = await performBackgroundSync(
        driveServiceBuilder: () => mockDriveService,
      );

      expect(result, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(DriveService.lastBackgroundSyncStatusKey),
        contains('Failed: Exception: Sync failed Network error'),
      );
    });
  });

  group('BackgroundSyncService error handling', () {
    test('initialize handles Workmanager error gracefully', () async {
      when(
        () => mockWorkmanager.initialize(
          any(),
        ),
      ).thenThrow(Exception('Workmanager init error'));

      final service = BackgroundSyncService(workmanager: mockWorkmanager);
      await expectLater(service.initialize(), completes);
    });

    test('registerPeriodicSync handles Workmanager error gracefully', () async {
      when(
        () => mockWorkmanager.registerPeriodicTask(
          any(),
          any(),
          frequency: any(named: 'frequency'),
          constraints: any(named: 'constraints'),
          existingWorkPolicy: any(named: 'existingWorkPolicy'),
        ),
      ).thenThrow(Exception('Register task error'));

      final service = BackgroundSyncService(workmanager: mockWorkmanager);
      await expectLater(service.registerPeriodicSync(), completes);
    });

    test('cancelSync handles Workmanager error gracefully', () async {
      when(
        () => mockWorkmanager.cancelByUniqueName(any()),
      ).thenThrow(Exception('Cancel task error'));

      final service = BackgroundSyncService(workmanager: mockWorkmanager);
      await expectLater(service.cancelSync(), completes);
    });

    test('BackgroundSyncService default constructor instantiates Workmanager', () {
      final service = BackgroundSyncService();
      expect(service, isNotNull);
    });

    test('callbackDispatcher runs without throwing', () {
      expect(() => callbackDispatcher(), returnsNormally);
    });

    test('executeBackgroundTask calls performSyncOverride for matching task', () async {
      bool syncCalled = false;
      final result = await executeBackgroundTask(
        backgroundSyncTaskName,
        null,
        performSyncOverride: () async {
          syncCalled = true;
          return true;
        },
      );
      expect(result, isTrue);
      expect(syncCalled, isTrue);
    });

    test('executeBackgroundTask returns true for unmatched task name', () async {
      final result = await executeBackgroundTask(
        'some_other_task',
        null,
      );
      expect(result, isTrue);
    });
  });


  group('DriveService Background Sync Settings', () {
    test('setBackgroundSyncEnabled updates preferences and notifies listeners', () async {
      SharedPreferences.setMockInitialValues({});
      final service = DriveService();
      await service.init();
      expect(service.isBackgroundSyncEnabled, isTrue);

      bool notified = false;
      service.addListener(() => notified = true);

      await service.setBackgroundSyncEnabled(false);
      expect(service.isBackgroundSyncEnabled, isFalse);
      expect(notified, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(DriveService.backgroundSyncEnabledKey), isFalse);
    });

    test('setBackgroundSyncWifiOnly updates preferences and notifies listeners', () async {
      SharedPreferences.setMockInitialValues({});
      final service = DriveService();
      await service.init();
      expect(service.isBackgroundSyncWifiOnly, isTrue);

      bool notified = false;
      service.addListener(() => notified = true);

      await service.setBackgroundSyncWifiOnly(false);
      expect(service.isBackgroundSyncWifiOnly, isFalse);
      expect(notified, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(DriveService.backgroundSyncWifiOnlyKey), isFalse);
    });

    test('init loads saved background sync status and time', () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        DriveService.backgroundSyncEnabledKey: false,
        DriveService.backgroundSyncWifiOnlyKey: false,
        DriveService.lastBackgroundSyncTimeKey: now.toIso8601String(),
        DriveService.lastBackgroundSyncStatusKey: 'Success',
      });

      final service = DriveService();
      await service.init();

      expect(service.isSyncing, isFalse);
      expect(service.lastSyncTime, isNull);
      expect(service.currentUser, isNull);
      expect(service.isBackgroundSyncEnabled, isFalse);
      expect(service.isBackgroundSyncWifiOnly, isFalse);
      expect(service.lastBackgroundSyncTime?.toIso8601String(), now.toIso8601String());
      expect(service.lastBackgroundSyncStatus, 'Success');
    });
  });
}


