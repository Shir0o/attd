import 'package:attendance_tracker/features/attendance/models/attendance_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AttendanceStatus labels are human readable', () {
    expect(AttendanceStatus.present.label, 'Present');
    expect(AttendanceStatus.absent.label, 'Absent');
  });
}
