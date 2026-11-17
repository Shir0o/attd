import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../domain/handoff_file.dart';

/// Reads the file the user chose in the system file picker. Resolves null when
/// they cancel. The size is checked before the bytes are read.
typedef PickHandoffBytes = Future<Uint8List?> Function();

Future<Uint8List?> pickHandoffFileBytes() async {
  final file = await FilePicker.pickFile(dialogTitle: 'Open handoff file');
  if (file == null) return null;
  final length = await file.length();
  if (length == null || length > HandoffLimits.maxBytes) {
    throw const HandoffFormatException(
      'This file is too large to be an Attendance Tracker handoff file.',
    );
  }
  return file.readAsBytes();
}

/// Files the operating system opens in the app: a tapped attachment, or one
/// shared to it. Android only for now; elsewhere nothing arrives and the
/// in-app picker is the way in.
///
/// The native side reads a bounded number of bytes and hands them over
/// untouched. Nothing is interpreted here either: the bytes go to
/// [HandoffCodec], which validates them.
class IncomingHandoffFiles {
  IncomingHandoffFiles({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'com.attd.tracker/handoff';

  final MethodChannel _channel;

  /// The file the app was launched to open, if any. Asking again returns null.
  Future<Uint8List?> takeInitialFile() async {
    try {
      return await _channel.invokeMethod<Uint8List>('getInitialFile');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Calls [onFile] for every file opened while the app is running.
  void listen(void Function(Uint8List bytes) onFile) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'fileOpened' && call.arguments is Uint8List) {
        onFile(call.arguments as Uint8List);
      }
    });
  }

  void dispose() => _channel.setMethodCallHandler(null);
}
