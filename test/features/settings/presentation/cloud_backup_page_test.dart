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
    when(service.listCloudBackups).thenAnswer((_) async => []);

    await tester.pumpWidget(
      _wrap(CloudBackupPage(driveService: service, disableAnimations: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cloud Version History'), findsOneWidget);
    expect(find.text('No Cloud Backups'), findsOneWidget);
    verify(service.listCloudBackups).called(1);
  });

  testWidgets('lists backups and restores confirmed backup', (tester) async {
    final service = _MockDriveService();
    final backup = drive.File()
      ..id = 'backup-1'
      ..createdTime = DateTime(2025, 2, 3, 14, 30);

    when(service.listCloudBackups).thenAnswer((_) async => [backup]);
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

    expect(find.textContaining('Monday, Feb 3'), findsOneWidget);
    expect(find.text('Saved at 2:30 PM'), findsOneWidget);

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
    when(service.listCloudBackups).thenAnswer((_) async => [backup]);

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
    when(service.listCloudBackups).thenAnswer((_) async => [backup]);
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
    when(service.listCloudBackups).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw Exception('offline');
      }
      return [];
    });

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
}
