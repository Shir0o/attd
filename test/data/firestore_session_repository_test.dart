
import 'package:attendance_tracker/data/session.dart';
import 'package:attendance_tracker/data/session_record.dart';
import 'package:attendance_tracker/data/session_repository.dart';
import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreSessionRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreSessionRepository(firestore: firestore);
  });

  final testRecord = SessionRecord(
    attendee: 'test-user',
    status: AttendanceStatus.present,
    recordedAt: DateTime.now(),
    recordedBy: 'admin',
  );

  test('createSession creates document and first version', () async {
    final session = await repository.createSession(
      title: 'Test Session',
      sessionDate: DateTime(2023, 1, 1),
      actor: 'admin',
      records: [testRecord],
    );

    expect(session.currentVersion, equals(1));

    // Verify main doc
    final doc = await firestore.collection('sessions').doc(session.id).get();
    expect(doc.exists, isTrue);
    expect(doc.data()?['title'], equals('Test Session'));

    // Verify version doc
    final versionParam = await firestore
        .collection('sessions')
        .doc(session.id)
        .collection('versions')
        .doc('1')
        .get();
    expect(versionParam.exists, isTrue);
    expect(versionParam.data()?['version'], equals(1));
  });

  test('saveSnapshot creates new version', () async {
    final session = await repository.createSession(
      title: 'Test Session',
      sessionDate: DateTime(2023, 1, 1),
      actor: 'admin',
      records: [testRecord],
    );

    await repository.saveSnapshot(session, actor: 'admin');

    final updated = await firestore.collection('sessions').doc(session.id).get();
    expect(updated.data()?['currentVersion'], equals(2));

    final history = await repository.history(session.id);
    expect(history.length, equals(2));
    expect(history.first.version, equals(2));
  });

  test('revertToPrevious restores previous state', () async {
    final session = await repository.createSession(
      title: 'Original Title',
      sessionDate: DateTime(2023, 1, 1),
      actor: 'admin',
      records: [],
    );

    // Make a change
    final modified = session.copyWith(title: 'Modified Title');
    await repository.saveSnapshot(modified, actor: 'admin');
    
    // Verify modification
    final current = await firestore.collection('sessions').doc(session.id).get();
    expect(current.data()?['title'], equals('Modified Title'));
    expect(current.data()?['currentVersion'], equals(2));

    // Revert
    final reverted = await repository.revertToPrevious(session.id, actor: 'admin');
    expect(reverted, isNotNull);
    expect(reverted!.title, equals('Original Title'));
    expect(reverted.currentVersion, equals(3)); // Revert is a new version
  });
}
