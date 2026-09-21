import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../../../core/design/app_radii.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
import '../../../core/logging/app_logger.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../../../data/session_repository.dart';
import '../data/event_repository.dart';
import '../data/event_sharing_service.dart';
import '../domain/event.dart';

final _log = AppLogger('ShareEventSheet');

class ShareEventSheet extends StatefulWidget {
  const ShareEventSheet({
    super.key,
    required this.event,
    required this.eventSharingService,
    required this.eventRepository,
    required this.attendanceRepository,
    required this.sessionRepository,
  });

  final Event event;
  final EventSharingService eventSharingService;
  final EventRepository eventRepository;
  final AttendanceRepository attendanceRepository;
  final SessionRepository sessionRepository;

  static Future<void> show(
    BuildContext context, {
    required Event event,
    required EventSharingService eventSharingService,
    required EventRepository eventRepository,
    required AttendanceRepository attendanceRepository,
    required SessionRepository sessionRepository,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => ShareEventSheet(
        event: event,
        eventSharingService: eventSharingService,
        eventRepository: eventRepository,
        attendanceRepository: attendanceRepository,
        sessionRepository: sessionRepository,
      ),
    );
  }

  @override
  State<ShareEventSheet> createState() => _ShareEventSheetState();
}

class _ShareEventSheetState extends State<ShareEventSheet> {
  final _emailController = TextEditingController();
  bool _isLoading = true;
  bool _isActionLoading = false;
  late Event _event;
  List<drive.Permission> _permissions = [];

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _loadCollaborators();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadCollaborators() async {
    setState(() => _isLoading = true);
    if (_event.isShared && _event.sharedFolderId != null) {
      try {
        final perms = await widget.eventSharingService.listCollaborators(
          _event.sharedFolderId!,
        );
        if (mounted) {
          setState(() {
            // Filter out the owner/organizer or keep writer permissions
            _permissions = perms
                .where((p) => p.role == 'writer' && p.type == 'user')
                .toList();
          });
        }
      } catch (e) {
        _log.warning('Failed to load collaborators: $e');
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _enableSharing() async {
    setState(() => _isActionLoading = true);
    try {
      final folderId = await widget.eventSharingService.createSharedEventFolder(_event);
      final families = await widget.attendanceRepository.fetchFamilies();
      final allMembers = families.expand((f) => f.members).toList();
      final sessions = await widget.sessionRepository.loadSessions();

      final slice = EventSharingService.generateSharedSlice(
        event: _event,
        allMembers: allMembers,
        sessions: sessions,
      );
      await widget.eventSharingService.uploadSharedSlice(folderId, slice);

      final updatedEvent = _event.copyWith(
        isShared: true,
        sharedFolderId: folderId,
        updatedAt: DateTime.now(),
      );
      await widget.eventRepository.updateEvent(updatedEvent);

      if (mounted) {
        setState(() {
          _event = updatedEvent;
        });
      }
      await _loadCollaborators();
    } catch (e) {
      _log.error('Failed to enable event sharing', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share event: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _disableSharing() async {
    setState(() => _isActionLoading = true);
    try {
      if (_event.sharedFolderId != null) {
        await widget.eventSharingService.unshareEvent(_event.sharedFolderId!);
      }

      final updatedEvent = _event.copyWith(
        isShared: false,
        collaborators: [],
        updatedAt: DateTime.now(),
      );
      await widget.eventRepository.updateEvent(updatedEvent);

      if (mounted) {
        setState(() {
          _event = updatedEvent;
          _permissions.clear();
        });
      }
    } catch (e) {
      _log.error('Failed to unshare event', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unshare event: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _inviteCollaborator() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) return;

    setState(() => _isActionLoading = true);
    try {
      if (_event.sharedFolderId == null) {
        await _enableSharing();
      }

      final folderId = _event.sharedFolderId;
      if (folderId != null) {
        await widget.eventSharingService.inviteCollaborator(folderId, email);
        final updatedCollaborators = List<String>.from(_event.collaborators)..add(email);
        final updatedEvent = _event.copyWith(
          collaborators: updatedCollaborators,
          updatedAt: DateTime.now(),
        );
        await widget.eventRepository.updateEvent(updatedEvent);

        if (mounted) {
          setState(() {
            _event = updatedEvent;
            _emailController.clear();
          });
        }
        await _loadCollaborators();
      }
    } catch (e) {
      _log.error('Failed to invite collaborator', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to invite collaborator: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _revokeCollaborator(drive.Permission permission) async {
    final permId = permission.id;
    final folderId = _event.sharedFolderId;
    if (permId == null || folderId == null) return;

    setState(() => _isActionLoading = true);
    try {
      await widget.eventSharingService.revokeCollaborator(folderId, permId);
      final email = permission.emailAddress;
      final updatedCollaborators = List<String>.from(_event.collaborators)
        ..removeWhere((e) => e == email);

      final updatedEvent = _event.copyWith(
        collaborators: updatedCollaborators,
        updatedAt: DateTime.now(),
      );
      await widget.eventRepository.updateEvent(updatedEvent);

      if (mounted) {
        setState(() {
          _event = updatedEvent;
        });
      }
      await _loadCollaborators();
    } catch (e) {
      _log.error('Failed to revoke collaborator', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to revoke collaborator: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.conv;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: AppRadii.sheetR,
      ),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 32),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: c.ink4.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Share Event',
                        style: AppTypography.fraunces(
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          color: c.ink,
                          letterSpacing: -0.48,
                          height: 1.15,
                        ),
                      ),
                    ),
                    if (_event.isShared)
                      ConvPill(
                        label: 'SHARED',
                        isOn: true,
                        fontSize: 10,
                        letterSpacing: 1.0,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Allow other users with Google Drive to take attendance for ${_event.title}. '
                  'Only assigned members and attendance marks are shared.',
                  style: AppTypography.geist(
                    fontSize: 14,
                    color: c.ink2,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),

                // Toggle share status
                ConvCardSoft(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Share this event',
                        style: AppTypography.geist(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: c.ink,
                        ),
                      ),
                      Switch(
                        key: const Key('shareEventSwitch'),
                        value: _event.isShared,
                        onChanged: _isActionLoading
                            ? null
                            : (val) {
                                if (val) {
                                  _enableSharing();
                                } else {
                                  _disableSharing();
                                }
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (_event.isShared) ...[
                  ConvEyebrow('Add Collaborator'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('addCollaboratorEmailInput'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'colleague@gmail.com',
                            hintStyle: TextStyle(color: c.ink4),
                            filled: true,
                            fillColor: c.cardSoft,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _inviteCollaborator(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConvIconButton(
                        key: const Key('inviteCollaboratorBtn'),
                        icon: Icons.send,
                        color: c.primary,
                        onPressed: _isActionLoading ? null : _inviteCollaborator,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  ConvEyebrow('Collaborators'),
                  const SizedBox(height: 8),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_permissions.isEmpty && _event.collaborators.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No collaborators invited yet.',
                        style: AppTypography.geist(fontSize: 14, color: c.ink3),
                      ),
                    )
                  else ...[
                    // Render permissions or saved collaborator emails
                    for (final perm in _permissions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ConvCardSoft(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              ConvAvatar(
                                letter: (perm.emailAddress != null &&
                                        perm.emailAddress!.isNotEmpty)
                                    ? perm.emailAddress![0].toUpperCase()
                                    : 'C',
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      perm.displayName ?? perm.emailAddress ?? 'Collaborator',
                                      style: AppTypography.geist(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: c.ink,
                                      ),
                                    ),
                                    if (perm.displayName != null && perm.emailAddress != null)
                                      Text(
                                        perm.emailAddress!,
                                        style: AppTypography.geist(
                                          fontSize: 12,
                                          color: c.ink3,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              ConvIconButton(
                                key: Key('revoke_${perm.id}'),
                                icon: Icons.remove_circle_outline,
                                color: c.absent,
                                onPressed: _isActionLoading
                                    ? null
                                    : () => _revokeCollaborator(perm),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
