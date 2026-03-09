import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:attendance_tracker/features/attendance/models/family.dart';
import 'package:attendance_tracker/features/attendance/models/member.dart';
import 'package:attendance_tracker/features/attendance/utils/name_corrections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('applyNameCorrection renames members and duplicates together', () {
    final families = [
      Family(
        id: 'fam-1',
        displayName: 'Kim Family',
        members: [
          Member(id: 'mem-1', displayName: 'Alex K.'),
          Member(
            id: 'mem-2',
            displayName: 'A. Kim',
            defaultStatus: AttendanceStatus.present,
          ),
        ],
      ),
    ];

    final result = applyNameCorrection(
      families: families,
      subject: 'Alex K.',
      correctedName: 'Alex Kim',
      duplicateCandidates: const ['A. Kim'],
    );

    expect(result.first.members[0].displayName, 'Alex Kim');
    expect(result.first.members[1].displayName, 'Alex Kim');
  });

  test('applyNameCorrection updates family names when provided', () {
    final families = [
      Family(id: 'fam-1', displayName: 'Patel Family', members: []),
      Family(id: 'fam-2', displayName: 'Rivera Fam', members: []),
    ];

    final result = applyNameCorrection(
      families: families,
      subject: 'Patel Family',
      correctedName: 'Patel Household',
      duplicateCandidates: const ['Rivera Fam'],
    );

    expect(result[0].displayName, 'Patel Household');
    expect(result[1].displayName, 'Patel Household');
  });
}
