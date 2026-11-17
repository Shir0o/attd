import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/handoff_file.dart';

typedef HandoffShareFiles = Future<void> Function(
  List<XFile> files, {
  String? text,
});

/// Writes a handoff or result file and opens the system share sheet with it
/// attached. The owner or helper picks who receives it; the app keeps no
/// recipient list and sends nothing itself.
class HandoffSharer {
  HandoffSharer({
    Future<Directory> Function()? directoryProvider,
    HandoffShareFiles? shareFiles,
  })  : _directoryProvider = directoryProvider ?? getTemporaryDirectory,
        _shareFiles = shareFiles ??
            ((files, {text}) => Share.shareXFiles(files, text: text));

  final Future<Directory> Function() _directoryProvider;
  final HandoffShareFiles _shareFiles;

  static const String _folderName = 'handoff';

  /// A file name made only of lowercase letters, digits and hyphens, so
  /// nothing typed into an event title can reach the path.
  static String fileNameFor(String title, DateTime date, {String? suffix}) {
    var slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.length > 40) {
      slug = slug.substring(0, 40).replaceAll(RegExp(r'-+$'), '');
    }
    if (slug.isEmpty) slug = 'event';
    final day = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final tail = suffix == null ? '' : '-$suffix';
    return '$slug-$day$tail.$handoffFileExtension';
  }

  /// Writes [document] under [fileName] and shares it with [text] as the
  /// message. Earlier files left in the folder are cleared first.
  Future<void> send({
    required HandoffDocument document,
    required String fileName,
    required String text,
  }) async {
    final Uint8List bytes = HandoffCodec.encodeBytes(document);
    final base = await _directoryProvider();
    final dir = Directory(p.join(base.path, _folderName));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
    final path = p.join(dir.path, p.basename(fileName));
    await File(path).writeAsBytes(bytes, flush: true);
    await _shareFiles(
      [XFile(path, mimeType: handoffMimeType, name: p.basename(fileName))],
      text: text,
    );
  }
}
