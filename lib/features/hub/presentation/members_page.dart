import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';
import '../data/event_repository.dart';
import '../domain/event.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({
    super.key,
    required this.attendanceRepository,
    this.event,
    this.eventRepository,
  });

  final AttendanceRepository attendanceRepository;
  final Event? event;
  final EventRepository? eventRepository;

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  List<Family>? _families;
  bool _isLoading = true;
  Object? _error;
  Event? _currentEvent; // To track local changes to the event
  bool _isAdding = false;

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    _loadFamilies(isInitial: true);
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
      final remaining = const Duration(milliseconds: 600) - elapsed;

      if (remaining > Duration.zero) {
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

  Future<void> _editMember(Member member) async {
    if (_families == null) return;

    final controller = TextEditingController(text: member.displayName);
    final focusNode = FocusNode();

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Member'),
        content: TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Member Name'),
          autofocus: true,
          onSubmitted: (val) => Navigator.of(context).pop(val),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
    focusNode.dispose();

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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove "${member.displayName}"? This will not delete their historical attendance records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
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
                duration: const Duration(milliseconds: 600),
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
        separatorBuilder: (ctx, i) =>
            Divider(color: colorScheme.outlineVariant, height: 1),
        itemBuilder: (context, index) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.05),
            ),
            title: Container(
              width: 150,
              height: 16,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            subtitle: Container(
              width: 80,
              height: 12,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
              ),
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
    if (isEventMode) {
      filteredMembers.sort((a, b) {
        final aSelected = _currentEvent!.memberIds.contains(a.id);
        final bSelected = _currentEvent!.memberIds.contains(b.id);
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
                      ? '${_currentEvent!.memberIds.length} / ${filteredMembers.length}'
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
            separatorBuilder: (ctx, i) =>
                Divider(color: colorScheme.outlineVariant, height: 1),
            itemBuilder: (context, index) {
              final member = filteredMembers[index];
              final isSelected = isEventMode
                  ? _currentEvent!.memberIds.contains(member.id)
                  : false;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: isEventMode
                    ? () => _toggleEventMember(member, !isSelected)
                    : null,
                leading: CircleAvatar(
                  backgroundColor: isSelected
                      ? colorScheme.primary
                      : colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    member.displayName.isNotEmpty
                        ? member.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  member.displayName,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: isSelected
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
                subtitle: isEventMode && isSelected
                    ? Text(
                        'Assigned',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.primary,
                        ),
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () => _editMember(member),
                    ),
                    if (isEventMode)
                      Checkbox(
                        value: isSelected,
                        onChanged: (val) =>
                            _toggleEventMember(member, val ?? false),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => _deleteMember(member),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
