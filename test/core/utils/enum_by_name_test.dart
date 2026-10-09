import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_tracker/core/utils/enum_by_name.dart';

enum _SampleEnum { alpha, beta, gamma }

void main() {
  group('enumByNameOrNull', () {
    test('returns matching enum value for matching string', () {
      expect(enumByNameOrNull(_SampleEnum.values, 'alpha'), _SampleEnum.alpha);
      expect(enumByNameOrNull(_SampleEnum.values, 'beta'), _SampleEnum.beta);
      expect(enumByNameOrNull(_SampleEnum.values, 'gamma'), _SampleEnum.gamma);
    });

    test('returns null for null name', () {
      expect(enumByNameOrNull(_SampleEnum.values, null), isNull);
    });

    test('returns null for unknown string', () {
      expect(enumByNameOrNull(_SampleEnum.values, 'unknown'), isNull);
      expect(enumByNameOrNull(_SampleEnum.values, ''), isNull);
    });
  });
}
