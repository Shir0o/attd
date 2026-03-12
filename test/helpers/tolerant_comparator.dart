import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [LocalFileComparator] that allows for a small amount of difference
/// between the golden file and the rendered image.
///
/// This is useful for cross-platform golden tests where slight rendering
/// differences (e.g. anti-aliasing, font fallbacks) are expected.
class TolerantComparator extends LocalFileComparator {
  TolerantComparator(super.testFile, {this.precisionError = 0.05});

  /// The maximum allowed difference between the golden file and the rendered image.
  /// 0.05 means 5% difference is allowed.
  final double precisionError;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (!result.passed && result.diffPercent <= precisionError) {
      debugPrint(
        'Golden file difference of ${(result.diffPercent * 100).toStringAsFixed(2)}% '
        'is within tolerance of ${(precisionError * 100).toStringAsFixed(2)}%. Passing.',
      );
      return true;
    }

    if (!result.passed) {
      final error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(error);
    }
    return true;
  }
}

/// Sets the [goldenFileComparator] to a [TolerantComparator] for the current test.
void setupTolerantComparator(String testFilePath, {double precisionError = 0.05}) {
  if (goldenFileComparator is LocalFileComparator) {
    final testUrl = (goldenFileComparator as LocalFileComparator).basedir;
    goldenFileComparator = TolerantComparator(
      Uri.parse('$testUrl$testFilePath'),
      precisionError: precisionError,
    );
  }
}
