import 'dart:convert';

import 'package:attendance_tracker/core/design/app_shimmer.dart';
import 'package:attendance_tracker/features/settings/data/drive_service.dart';
import 'package:attendance_tracker/features/settings/presentation/cloud_backup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:mocktail/mocktail.dart';

class _MockDriveService extends Mock implements DriveService {}

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('shows empty cloud backup state', (tester) async {
    final service = _MockDriveService();
    when(() => service.listCloudBackups()).thenAnswer((_) async => []);
    when(() => service.lastSyncTime).thenReturn(null);

    await tester.pumpWidget(
      _wrap(CloudBackupPage(driveService: service, disableAnimations: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('VERSION HISTORY'), findsOneWidget);
    expect(find.text('No Cloud Backups'), findsOneWidget);
    verify(() => service.listCloudBackups()).called(1);
  });

  testWidgets('crossfades its skeleton into the backups after 1200 ms (#222 M7)',
      (tester) async {
    final service = _MockDriveService();
    when(() => service.listCloudBackups()).thenAnswer((_) async => []);
    when(() => service.lastSyncTime).thenReturn(null);

    await tester.pumpWidget(_wrap(CloudBackupPage(driveService: service)));
    final content = find.text('No Cloud Backups');
    expect(find.byType(AppShimmer), findsWidgets);
    expect(content, findsNothing);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AppShimmer), findsWidgets, reason: 'still fading out');
    expect(content, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(AppShimmer), findsNothing);
    expect(content, findsOneWidget);
  });

  testWidgets('lists backups and restores confirmed backup', (tester) async {
    final service = _MockDriveService();
    final backup = drive.File()
      ..id = 'backup-1'
      ..createdTime = DateTime(2025, 2, 3, 14, 30);

    when(() => service.listCloudBackups()).thenAnswer((_) async => [backup]);
    when(() => service.lastSyncTime).thenReturn(null);
    when(
      () => service.restoreFromBackup(
        'backup-1',
        backupDateLabel: any(named: 'backupDateLabel'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      _wrap(CloudBackupPage(driveService: service, disableAnimations: true)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Feb 3 · 14:30'), findsOneWidget);

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(find.text('Restore from Cloud'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await tester.pumpAndSettle();

    verify(
      () => service.restoreFromBackup(
        'backup-1',
        backupDateLabel: 'Feb 3, 14:30',
      ),
    ).called(1);
  });

  testWidgets('Cancel button dismisses the restore confirmation dialog',
      (tester) async {
    final service = _MockDriveService();
    final backup = drive.File()
      ..id = 'backup-1'
      ..createdTime = DateTime(2025, 2, 3, 14, 30);
    when(() => service.listCloudBackups()).thenAnswer((_) async => [backup]);
    when(() => service.lastSyncTime).thenReturn(null);

    await tester.pumpWidget(
      _wrap(CloudBackupPage(driveService: service, disableAnimations: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Restore from Cloud'), findsNothing);
    verifyNever(() => service.restoreFromBackup(any(),
        backupDateLabel: any(named: 'backupDateLabel')));
  });

  testWidgets('shows a failure snackbar when restore throws',
      (tester) async {
    final service = _MockDriveService();
    final backup = drive.File()
      ..id = 'backup-1'
      ..createdTime = DateTime(2025, 2, 3, 14, 30);
    when(() => service.listCloudBackups()).thenAnswer((_) async => [backup]);
    when(() => service.lastSyncTime).thenReturn(null);
    when(() => service.restoreFromBackup(any(),
            backupDateLabel: any(named: 'backupDateLabel')))
        .thenThrow(Exception('network unavailable'));

    await tester.pumpWidget(
      _wrap(CloudBackupPage(driveService: service, disableAnimations: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Restoration failed'), findsOneWidget);
  });

  testWidgets('shows load failure and retries', (tester) async {
    final service = _MockDriveService();
    var calls = 0;
    when(() => service.listCloudBackups()).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw Exception('offline');
      }
      return [];
    });
    when(() => service.lastSyncTime).thenReturn(null);

    await tester.pumpWidget(
      _wrap(CloudBackupPage(driveService: service, disableAnimations: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load history'), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('No Cloud Backups'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('shows current badge and hides restore button when in sync',
      (tester) async {
    final service = _MockDriveService();
    final backup = drive.File()
      ..id = 'backup-1'
      ..createdTime = DateTime.now().subtract(const Duration(minutes: 5));

    when(() => service.listCloudBackups()).thenAnswer((_) async => [backup]);
    when(() => service.lastSyncTime).thenReturn(DateTime.now());

    await tester.pumpWidget(
      _wrap(CloudBackupPage(driveService: service, disableAnimations: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Restore'), findsNothing);
  });

  testWidgets('Overwrite Cloud success and error', (tester) async {
    final service = _MockDriveService();
    when(() => service.listCloudBackups()).thenAnswer((_) async => []);
    when(() => service.lastSyncTime).thenReturn(null);
    when(() => service.overwriteCloudWithLocal()).thenAnswer((_) async {});

    await tester.pumpWidget(
      _wrap(CloudBackupPage(driveService: service, disableAnimations: true)),
    );
    await tester.pumpAndSettle();

    // Verify buttons are rendered
    expect(find.text('Overwrite cloud'), findsOneWidget);
    expect(find.text('Overwrite local'), findsOneWidget);

    // Tap Overwrite cloud
    await tester.tap(find.text('Overwrite cloud'));
    await tester.pumpAndSettle();
    expect(find.text('Overwrite Cloud Data?'), findsOneWidget);

    // Cancel first
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => service.overwriteCloudWithLocal());

    // Tap Overwrite cloud again and confirm
    await tester.tap(find.text('Overwrite cloud'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Overwrite'));
    await tester.pumpAndSettle();
    verify(() => service.overwriteCloudWithLocal()).called(1);
    expect(find.text('Cloud data overwritten'), findsOneWidget);

    // Error path
    when(() => service.overwriteCloudWithLocal()).thenThrow(Exception('overwrite failed'));
    ScaffoldMessenger.of(tester.element(find.byType(CloudBackupPage))).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Overwrite cloud'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Overwrite'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Error: Exception: overwrite failed'), findsOneWidget);
  });

  testWidgets('Overwrite Local success and error', (tester) async {
    final service = _MockDriveService();
    when(() => service.listCloudBackups()).thenAnswer((_) async => []);
    when(() => service.lastSyncTime).thenReturn(null);
    when(() => service.overwriteLocalWithCloud()).thenAnswer((_) async {});

    await tester.pumpWidget(
      _wrap(CloudBackupPage(driveService: service, disableAnimations: true)),
    );
    await tester.pumpAndSettle();

    // Tap Overwrite local
    await tester.tap(find.text('Overwrite local'));
    await tester.pumpAndSettle();
    expect(find.text('Overwrite Local Data?'), findsOneWidget);

    // Cancel first
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => service.overwriteLocalWithCloud());

    // Tap Overwrite local again and confirm
    await tester.tap(find.text('Overwrite local'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Overwrite'));
    await tester.pumpAndSettle();
    verify(() => service.overwriteLocalWithCloud()).called(1);
    expect(find.text('Local data overwritten'), findsOneWidget);

    // Error path
    when(() => service.overwriteLocalWithCloud()).thenThrow(Exception('overwrite failed'));
    ScaffoldMessenger.of(tester.element(find.byType(CloudBackupPage))).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Overwrite local'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Overwrite'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Error: Exception: overwrite failed'), findsOneWidget);
  });

  testWidgets('Overwrite local and Overwrite cloud cards render with equal height',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _MockDriveService();
    when(() => service.listCloudBackups()).thenAnswer((_) async => []);
    when(() => service.lastSyncTime).thenReturn(null);

    await tester.pumpWidget(
      _wrap(CloudBackupPage(driveService: service, disableAnimations: true)),
    );
    await tester.pumpAndSettle();

    final localCard = find.ancestor(
      of: find.text('Overwrite local'),
      matching: find.byType(Material),
    );
    final cloudCard = find.ancestor(
      of: find.text('Overwrite cloud'),
      matching: find.byType(Material),
    );

    final localSize = tester.getSize(localCard.first);
    final cloudSize = tester.getSize(cloudCard.first);
    expect(localSize.height, equals(cloudSize.height));
  });

  testWidgets('displays all summary tags and expandable exact item changes on snapshot row',
      (tester) async {
    final service = _MockDriveService();
    final backup = drive.File()
      ..id = 'backup-detailed'
      ..size = '4096'
      ..createdTime = DateTime(2026, 10, 20, 14, 30)
      ..description = jsonEncode({
        'title': 'Manual Drive Sync',
        'user': 'Tony',
        'tags': ['+1 Sessions', '+5 Members', 'Manual'],
        'changes': [
          'Added session · Sunday Service (Oct 20) · 32 present, 3 absent',
          'Added member · Alice Smith (Smith)',
          'Added member · Bob Smith (Smith)',
          'Added member · Charlie Smith (Smith)',
          'Added member · Diana Smith (Smith)',
          'Added member · Evan Smith (Smith)',
        ],
        'overflowChanges': 2,
      });

    when(() => service.listCloudBackups()).thenAnswer((_) async => [backup]);
    when(() => service.lastSyncTime).thenReturn(null);

    await tester.pumpWidget(
      _wrap(CloudBackupPage(driveService: service, disableAnimations: true)),
    );
    await tester.pumpAndSettle();

    // All tags are rendered, not just tags.first
    expect(find.text('+1 Sessions'), findsOneWidget);
    expect(find.text('+5 Members'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);

    // First 4 exact item changes are visible initially
    expect(
      find.text('Added session · Sunday Service (Oct 20) · 32 present, 3 absent'),
      findsOneWidget,
    );
    expect(find.text('Added member · Alice Smith (Smith)'), findsOneWidget);
    expect(find.text('Added member · Diana Smith (Smith)'), findsNothing);
    expect(find.text('Show 2 more changes'), findsOneWidget);

    // Expand to see all recorded changes + overflow indicator
    await tester.ensureVisible(find.text('Show 2 more changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show 2 more changes'));
    await tester.pumpAndSettle();

    expect(find.text('Added member · Diana Smith (Smith)'), findsOneWidget);
    expect(find.text('Added member · Evan Smith (Smith)'), findsOneWidget);
    expect(find.text('+2 more items changed'), findsOneWidget);
    expect(find.text('Show less'), findsOneWidget);

    // Collapse back to 4 items
    await tester.ensureVisible(find.text('Show less'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();

    expect(find.text('Added member · Diana Smith (Smith)'), findsNothing);
    expect(find.text('Show 2 more changes'), findsOneWidget);
  });
}
