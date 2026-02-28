import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  try {
    final screenshotDir = Platform.environment['SCREENSHOT_DIR'] ?? 'screenshots/default';
    await integrationDriver(
      onScreenshot: (String name, List<int> bytes, [Map<String, dynamic>? args]) async {
        final File image = File('$screenshotDir/$name.png');
        await image.create(recursive: true);
        await image.writeAsBytes(bytes);
        print('Screenshot saved to: ${image.path}');
        return true;
      },
    );
  } catch (e) {
    print('Error in integrationDriver: $e');
  }
}
