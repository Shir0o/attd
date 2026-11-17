import 'package:attendance_tracker/features/handoff/data/incoming_handoff_files.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(IncomingHandoffFiles.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('takeInitialFile returns the bytes the platform handed over', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getInitialFile');
      return Uint8List.fromList([1, 2, 3]);
    });
    expect(
      await IncomingHandoffFiles().takeInitialFile(),
      Uint8List.fromList([1, 2, 3]),
    );
  });

  test('takeInitialFile is null when nothing opened the app', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await IncomingHandoffFiles().takeInitialFile(), isNull);
  });

  test('takeInitialFile is null where the platform has no channel', () async {
    expect(await IncomingHandoffFiles().takeInitialFile(), isNull);
  });

  test('takeInitialFile is null when the platform reports an error', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'boom');
    });
    expect(await IncomingHandoffFiles().takeInitialFile(), isNull);
  });

  test('listen delivers files opened while running, and only those', () async {
    final received = <Uint8List>[];
    final incoming = IncomingHandoffFiles()..listen(received.add);

    Future<void> deliver(String method, Object? args) =>
        messenger.handlePlatformMessage(
          IncomingHandoffFiles.channelName,
          const StandardMethodCodec()
              .encodeMethodCall(MethodCall(method, args)),
          (_) {},
        );

    await deliver('fileOpened', Uint8List.fromList([9, 8]));
    await deliver('fileOpened', 'not bytes');
    await deliver('somethingElse', Uint8List.fromList([7]));

    expect(received, [Uint8List.fromList([9, 8])]);

    incoming.dispose();
    await deliver('fileOpened', Uint8List.fromList([1]));
    expect(received, hasLength(1));
  });
}
