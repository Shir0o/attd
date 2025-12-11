
import 'package:attendance_tracker/features/attendance/data/attendance_repository.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreAttendanceRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreAttendanceRepository(firestore: firestore);
  });

  test('fetchFamilies seeds default data if empty', () async {
    final families = await repository.fetchFamilies();
    
    expect(families, isNotEmpty);
    expect(families.any((f) => f.displayName == 'Rivera Family'), isTrue);

    final snapshot = await firestore.collection('families').get();
    expect(snapshot.docs.length, equals(families.length));
  });

  test('fetchFamilies returns existing data', () async {
    await firestore.collection('families').doc('f1').set({
      'id': 'f1',
      'displayName': 'Test Family',
      'members': [],
    });

    final families = await repository.fetchFamilies();
    expect(families.length, equals(1));
    expect(families.first.displayName, equals('Test Family'));
  });

  test('saveFamilies updates data', () async {
    final family = Family(id: 'f1', displayName: 'New Family', members: []);
    await repository.saveFamilies([family]);

    final snapshot = await firestore.collection('families').doc('f1').get();
    expect(snapshot.exists, isTrue);
    expect(snapshot.data()?['displayName'], equals('New Family'));
  });

  test('addVisitor adds member to family', () async {
    // Setup initial family
    final family = Family(id: 'f1', displayName: 'Hosting Family', members: []);
    await repository.saveFamilies([family]);

    final visitor = Member(id: 'v1', displayName: 'Visitor 1', isVisitor: true);
    
    final updatedFamily = await repository.addMember('f1', visitor);
    
    expect(updatedFamily.members.length, equals(1));
    expect(updatedFamily.members.first.displayName, equals('Visitor 1'));

    final snapshot = await firestore.collection('families').doc('f1').get();
    final members = snapshot.data()?['members'] as List;
    expect(members.length, equals(1));
  });

  test('addFamily creates new family document', () async {
    final family = await repository.addFamily('New Family');
    
    expect(family.displayName, equals('New Family'));
    expect(family.members, isEmpty);
    expect(family.id, isNotEmpty);

    final snapshot = await firestore.collection('families').doc(family.id).get();
    expect(snapshot.exists, isTrue);
    expect(snapshot.data()?['displayName'], equals('New Family'));
  });
}
