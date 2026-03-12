import 'session.dart';

class SessionVersion {
  SessionVersion({
    required this.sessionId,
    required this.version,
    required this.snapshot,
    required this.recordedAt,
    required this.actor,
  });

  final String sessionId;
  final int version;
  final Session snapshot;
  final DateTime recordedAt;
  final String actor;
}
