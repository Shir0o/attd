import 'session.dart';

class SessionVersion {
  const SessionVersion({
    required this.sessionId,
    required this.version,
    required this.snapshot,
    required this.recordedAt,
    required this.actor,
    this.isDeleted = false,
  });

  final String sessionId;
  final int version;
  final Session snapshot;
  final DateTime recordedAt;
  final String actor;
  final bool isDeleted;
}
