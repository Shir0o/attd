import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/handoff_service.dart';
import '../domain/handoff_file.dart';
import 'import_result_page.dart';

/// Where an opened file goes: validated, then either added as someone else's
/// event (a handoff) or shown for review (a result). Whatever is in the file
/// is data: it is never followed, run or used as a route.
class HandoffIntake {
  HandoffIntake({
    required this.navigatorKey,
    required this.service,
    this.disableAnimations = false,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final HandoffService service;
  final bool disableAnimations;

  Future<void> open(Uint8List bytes) async {
    final HandoffDocument doc;
    try {
      doc = HandoffCodec.decodeBytes(bytes);
    } on HandoffFormatException catch (e) {
      await _tell('Could not open the file', e.message);
      return;
    }

    switch (doc) {
      case final HandoffRoster roster:
        try {
          final event = await service.receive(roster);
          await _tell(
            'Added to your events',
            '"${event.title}" is on your home screen, marked as someone '
                'else\'s. Tap it to start marking, then send the marks back '
                'when you are done.',
          );
        } on HandoffFormatException catch (e) {
          await _tell('Could not add this event', e.message);
        } catch (_) {
          await _tell(
            'Could not add this event',
            'Something went wrong saving it. Nothing was changed.',
          );
        }
      case final HandoffResult result:
        final nav = navigatorKey.currentState;
        if (nav == null) return;
        await nav.push(
          MaterialPageRoute<void>(
            builder: (_) => ImportResultPage(
              result: result,
              service: service,
              disableAnimations: disableAnimations,
            ),
          ),
        );
    }
  }

  Future<void> _tell(String title, String message) async {
    final nav = navigatorKey.currentState;
    final context = navigatorKey.currentContext;
    if (nav == null || context == null) return;
    await nav.push(
      DialogRoute<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}
