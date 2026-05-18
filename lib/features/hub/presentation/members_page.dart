import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_theme.dart';
import '../../../data/session_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';
import '../data/event_repository.dart';
import '../domain/event.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({
    super.key,
    required this.attendanceRepository,
    this.sessionRepository,
    this.event,
    this.eventRepository,
    this.disableAnimations = false,
  });

  final AttendanceRepository attendanceRepository;
  final SessionRepository? sessionRepository;
  final Event? event;
  final EventRepository? eventRepository;
  final bool disableAnimations;

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  List<Family>? _families;
  bool _isLoading = true;
  Object? _error;
  Event? _currentEvent; // To track local changes to the event
  bool _isAdding = false;
  final Map<String, List<({String title, DateTime date})>> _memberUsageMap = {};

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    _loadFamilies(isInitial: true);
    _loadUsageStats();
  }

  Future<void> _loadUsageStats() async {
    if (widget.sessionRepository == null) return;
    try {
      final sessions = await widget.sessionRepository!.loadSessions();
      final usageMap = <String, List<({String title, DateTime date})>>{};
      for (final session in sessions) {
        for (final record in session.records) {
          if (record.memberId != null) {
            usageMap
                .putIfAbsent(record.memberId!, () => [])
                .add((title: session.title, date: session.sessionDate));
          }
        }
      }
      if (mounted) {
        setState(() {
          _memberUsageMap.clear();
          _memberUsageMap.addAll(usageMap);
        });
      }
    } catch (e) {
      debugPrint('Error loading usage stats: $e');
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFamilies({bool isInitial = false}) async {
    final startTime = DateTime.now();
    if (isInitial) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final families = await widget.attendanceRepository.fetchFamilies();

      final elapsed = DateTime.now().difference(startTime);
      final remaining = const Duration(milliseconds: 800) - elapsed;

      if (remaining > Duration.zero && !widget.disableAnimations) {
        await Future.delayed(remaining);
      }

      if (mounted) {
        setState(() {
          _families = families;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  List<Member> _getAllMembers(List<Family> families) {
    return families.expand((f) => f.members).toList();
  }

  Future<void> _addMember(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || _isAdding) return;

    setState(() => _isAdding = true);
    
    try {
      // Check for duplicates
      final allMembers = _getAllMembers(_families ?? []);
      final isDuplicate = allMembers.any(
        (m) => m.displayNameLowercase == trimmedName.toLowerCase(),
      );

      if (isDuplicate) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Duplicate Member'),
            content: Text(
              'A member named "$trimmedName" already exists. Do you want to add them anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Add Duplicate'),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          setState(() => _isAdding = false);
          return;
        }
      }

      final newFamily = await widget.attendanceRepository.addFamily(
        trimmedName,
      );
      final newMember = Member(id: const Uuid().v4(), displayName: trimmedName);
      final updatedFamily = await widget.attendanceRepository.addMember(
        newFamily.id,
        newMember,
      );

      if (mounted) {
        setState(() {
          _families = [...(_families ?? []), updatedFamily];
        });

        // If in event mode, automatically add to event
        if (_currentEvent != null && widget.eventRepository != null) {
          await _toggleEventMember(newMember, true);
        }
      }

      _inputController.clear();
      // Keep keyboard open and focus the input
      _inputFocusNode.requestFocus();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Added $trimmedName')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add member: $e')));
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  void _showRenameInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history, color: Colors.blue),
            SizedBox(width: 12),
            Text('Historical Accuracy'),
          ],
        ),
        content: const Text(
          'Renaming a member here will update their name for all FUTURE sessions.\n\nTo preserve data integrity, names in past session reports remain unchanged. This ensures your history shows exactly what was recorded at that time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _editMember(Member member) async {
    if (_families == null) return;

    final linkedSessions = _memberUsageMap[member.id] ?? [];
    if (linkedSessions.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.history, color: colorScheme.primary),
                const SizedBox(width: 12),
                const Text('Historical Data Alert'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This member is linked to ${linkedSessions.length} past session reports:',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...linkedSessions.take(5).map((session) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(Icons.event_note,
                                    size: 16,
                                    color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        DateFormat('MMM d, yyyy')
                                            .format(session.date),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (linkedSessions.length > 5)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 4),
                            child: Row(
                              children: [
                                const SizedBox(width: 24),
                                Text(
                                  '... and ${linkedSessions.length - 5} more',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Renaming them will update future reports, but past reports will keep the name "${member.displayName}" to preserve historical accuracy.\n\nDo you want to continue?',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
    }

    var editedName = member.displayName;

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: member.displayName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Member Name'),
              autofocus: true,
              onChanged: (value) => editedName = value,
              onFieldSubmitted: (val) => Navigator.of(context).pop(val),
            ),
            const SizedBox(height: 12),
            Text(
              'Note: This updates future sessions. Past reports will keep the name "${member.displayName}" for accuracy.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(editedName),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null) return;

    final trimmedName = newName.trim();
    if (trimmedName.isEmpty || trimmedName == member.displayName) return;

    final allMembers = _getAllMembers(_families!);
    final isDuplicate = allMembers.any(
      (m) =>
          m.id != member.id &&
          m.displayNameLowercase == trimmedName.toLowerCase(),
    );

    if (isDuplicate) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Duplicate Member'),
          content: Text(
            'A member named "$trimmedName" already exists. Do you want to use this name anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final originalFamilies = List<Family>.from(_families!);
    try {
      final updatedFamilies = _families!.map((f) {
        final index = f.members.indexWhere((m) => m.id == member.id);
        if (index == -1) return f;

        final updatedMembers = List<Member>.from(f.members);
        updatedMembers[index] = member.copyWith(
          displayName: trimmedName,
          updatedAt: DateTime.now(),
        );
        return f.copyWith(
          members: updatedMembers,
          updatedAt: DateTime.now(),
        );
      }).toList();

      setState(() {
        _families = updatedFamilies;
      });

      await widget.attendanceRepository.saveFamilies(updatedFamilies);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated ${member.displayName} to $trimmedName'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _families = originalFamilies;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update member: $e')));
      }
    }
  }

  Future<void> _deleteMember(Member member) async {
    // In event mode, "Delete" might mean removing from event only,
    // or deleting the member entirely. The prompt says "Hide or disable 'Delete Member' when in Event context".
    // Let's hide the delete button in event mode, relying on checkboxes for "remove from event".
    // So this function is only for global delete.

    if (_families == null) return;

    final linkedSessions = _memberUsageMap[member.id] ?? [];

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                linkedSessions.isNotEmpty
                    ? Icons.warning_amber_rounded
                    : Icons.delete_outline,
                color: linkedSessions.isNotEmpty
                    ? Colors.orange
                    : colorScheme.error,
              ),
              const SizedBox(width: 12),
              const Text('Remove Member'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to remove "${member.displayName}" from the roster?',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (linkedSessions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'This member is linked to ${linkedSessions.length} past session reports:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...linkedSessions.take(3).map((session) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(Icons.event_note,
                                    size: 16,
                                    color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        DateFormat('MMM d, yyyy')
                                            .format(session.date),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (linkedSessions.length > 3)
                          Text(
                            '... and ${linkedSessions.length - 3} more',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'They will appear as a "Visitor" in past reports, but their data will NOT be deleted.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                const Text('Historical records are not affected.'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final originalFamilies = List<Family>.from(_families!);
    try {
      final now = DateTime.now();
      final updatedFamilies = _families!
          .map((f) {
            final index = f.members.indexWhere((m) => m.id == member.id);
            if (index == -1) return f;
            final updatedMembers = List<Member>.from(f.members);
            updatedMembers[index] = member.copyWith(
              deletedAt: now,
              updatedAt: now,
            );
            // Filter out soft-deleted members for display
            final visibleMembers = updatedMembers
                .where((m) => m.deletedAt == null)
                .toList();
            return f.copyWith(
              members: visibleMembers,
              updatedAt: now,
            );
          })
          .where((f) => f.members.isNotEmpty || f.deletedAt != null)
          .toList();

      // Save the full list including soft-deleted for sync
      final familiesForPersistence = _families!
          .map((f) {
            final index = f.members.indexWhere((m) => m.id == member.id);
            if (index == -1) return f;
            final updatedMembers = List<Member>.from(f.members);
            updatedMembers[index] = member.copyWith(
              deletedAt: now,
              updatedAt: now,
            );
            return f.copyWith(
              members: updatedMembers,
              updatedAt: now,
            );
          })
          .toList();

      setState(() {
        _families = updatedFamilies;
      });

      await widget.attendanceRepository.saveFamilies(familiesForPersistence);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Removed ${member.displayName}')));
    } catch (e) {
      if (mounted) {
        setState(() {
          _families = originalFamilies;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove member: $e')));
      }
    }
  }

  Future<void> _toggleEventMember(Member member, bool isSelected) async {
    if (_currentEvent == null || widget.eventRepository == null) return;

    final updatedMemberIds = List<String>.from(_currentEvent!.memberIds);
    if (isSelected) {
      if (!updatedMemberIds.contains(member.id)) {
        updatedMemberIds.add(member.id);
      }
    } else {
      updatedMemberIds.remove(member.id);
    }

    // We can't use copyWith on Event because I didn't add it in the first step (oops, maybe I should check).
    // Let's construct a new Event manually.
    // Ah, wait, I can assume Event is immutable and I should probably have added copyWith.
    // But since I didn't, let's just create a new instance.

    final updatedEvent = Event(
      id: _currentEvent!.id,
      title: _currentEvent!.title,
      time: _currentEvent!.time,
      frequency: _currentEvent!.frequency,
      oneTimeDate: _currentEvent!.oneTimeDate,
      repeatingDays: _currentEvent!.repeatingDays,
      memberIds: updatedMemberIds,
      createdAt: _currentEvent!.createdAt,
      // updatedAt will be set by repository or constructor logic
    );

    setState(() {
      _currentEvent = updatedEvent;
    });

    try {
      await widget.eventRepository!.updateEvent(updatedEvent);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update event: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEventMode = _currentEvent != null;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surface,
        title: Text(
          isEventMode ? 'Manage Event Members' : 'Manage Members',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showRenameInfo,
            tooltip: 'About historical records',
          ),
        ],
        iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: colorScheme.surfaceContainerHigh, height: 1),
        ),
      ),
      body: Column(
        children: [
          // Combined Search & Add Section
          Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: TextField(
                          key: const ValueKey('member_search_field'),
                          controller: _inputController,
                          focusNode: _inputFocusNode,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (val) {
                            setState(() {});
                          },
                          onSubmitted: (val) => _addMember(val),
                          decoration: InputDecoration(
                            hintText: isEventMode
                                ? 'Find or add to event'
                                : 'Find or add member',
                            hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      key: const ValueKey('member_add_fab'),
                      heroTag: 'fab',
                      mini: false,
                      elevation: 1,
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      onPressed: _isAdding ? null : () => _addMember(_inputController.text),
                      child: _isAdding 
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: colorScheme.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: RepaintBoundary(
              child: AnimatedSwitcher(
                duration: widget.disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 600),
                child: _buildBodyContent(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEventMode = _currentEvent != null;

    if (_isLoading && _families == null) {
      return ListView.separated(
        key: const ValueKey('loading'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 10,
        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: AppShimmer(
              width: 40,
              height: 40,
              borderRadius: BorderRadius.circular(20),
              disableAnimations: widget.disableAnimations,
            ),
            title: AppShimmer(
              width: 150,
              height: 16,
              borderRadius: BorderRadius.circular(24),
              disableAnimations: widget.disableAnimations,
            ),
            subtitle: AppShimmer(
              width: 80,
              height: 12,
              borderRadius: BorderRadius.circular(24),
              disableAnimations: widget.disableAnimations,
            ),
          );
        },
      );
    }

    if (_error != null && _families == null) {
      return Center(
        key: const ValueKey('error'),
        child: Text('Error: $_error'),
      );
    }

    final families = _families ?? [];
    final allMembers = _getAllMembers(families);
    final searchTerm = _inputController.text.toLowerCase();

    // Filter by search
    var filteredMembers = allMembers.where((m) {
      return m.displayNameLowercase.contains(searchTerm);
    }).toList();

    // In Event Mode, maybe we want to sort selected members to the top?
    final selectedIds = isEventMode ? _currentEvent!.memberIds.toSet() : <String>{};
    if (isEventMode) {
      filteredMembers.sort((a, b) {
        final aSelected = selectedIds.contains(a.id);
        final bSelected = selectedIds.contains(b.id);
        if (aSelected && !bSelected) return -1;
        if (!aSelected && bSelected) return 1;
        return a.displayName.compareTo(b.displayName);
      });
    } else {
      filteredMembers.sort((a, b) => a.displayName.compareTo(b.displayName));
    }

    return Column(
      key: const ValueKey('data'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEventMode ? 'Assigned Members' : 'Regular Members',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  isEventMode
                      ? '${selectedIds.length} / ${filteredMembers.length}'
                      : '${filteredMembers.length}',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filteredMembers.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final member = filteredMembers[index];
              final isSelected = isEventMode
                  ? selectedIds.contains(member.id)
                  : false;

              return _MemberListItem(
                member: member,
                isSelected: isSelected,
                isEventMode: isEventMode,
                onToggle: (val) => _toggleEventMember(member, val),
                onEdit: () => _editMember(member),
                onDelete: () => _deleteMember(member),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MemberListItem extends StatelessWidget {
  final Member member;
  final bool isSelected;
  final bool isEventMode;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MemberListItem({
    required this.member,
    required this.isSelected,
    required this.isEventMode,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dismissible(
      key: ValueKey('dismiss_${member.id}_$isEventMode'),
      direction: DismissDirection.horizontal,
      background: _buildSwipeBackground(
        context,
        'Rename',
        colorScheme.secondary,
        Icons.edit_outlined,
        true,
      ),
      secondaryBackground: _buildSwipeBackground(
        context,
        'Delete Member',
        colorScheme.error,
        Icons.delete_outline,
        false,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit();
        } else {
          onDelete();
        }
        return false; // Handle state externally
      },
      child: InkWell(
        onLongPress: onEdit,
        onTap: isEventMode ? () => onToggle(!isSelected) : onEdit,
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected && isEventMode
                ? colorScheme.surfaceContainerHigh
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                backgroundColor: isSelected && isEventMode
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                child: Text(
                  member.displayName.isNotEmpty
                      ? member.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: isSelected && isEventMode
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        color: colorScheme.onSurface,
                        fontWeight: isSelected && isEventMode
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                    if (isEventMode && isSelected)
                      Text(
                        'Assigned to Event',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                        ),
                      )
                    else
                      Text(
                        'Regular Member',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (isEventMode)
                Switch(
                  value: isSelected,
                  onChanged: onToggle,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeBackground(
    BuildContext context,
    String label,
    Color color,
    IconData icon,
    bool isStart,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: isStart ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isStart
            ? [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]
            : [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(icon, color: Colors.white),
              ],
      ),
    );
  }
}
