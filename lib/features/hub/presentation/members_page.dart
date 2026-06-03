import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_shimmer.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/conv_widgets.dart';
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
    this.selectionMode = false,
    this.initialSelectedMemberIds = const [],
  });

  final AttendanceRepository attendanceRepository;
  final SessionRepository? sessionRepository;
  final Event? event;
  final EventRepository? eventRepository;
  final bool disableAnimations;

  /// When true, the page acts as a non-persisting member picker: toggles only
  /// mutate local state and the chosen ids are returned via [Navigator.pop] when
  /// the user taps Done. Used by the new/edit-event form before the event exists.
  final bool selectionMode;

  /// Ids pre-selected when [selectionMode] is true.
  final List<String> initialSelectedMemberIds;

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  List<Family>? _families;
  bool _isLoading = true;
  Object? _error;
  Event? _currentEvent;
  late Set<String> _selectionIds;
  bool _isAdding = false;
  final Map<String, List<({String title, DateTime date})>> _memberUsageMap = {};

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    _selectionIds = widget.initialSelectedMemberIds.toSet();
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
        isAutoSingleton: true,
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

        if (widget.selectionMode) {
          setState(() => _selectionIds.add(newMember.id));
        } else if (_currentEvent != null && widget.eventRepository != null) {
          await _toggleEventMember(newMember, true);
        }
      }

      _inputController.clear();
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

  void _toggleSelection(Member member, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectionIds.add(member.id);
      } else {
        _selectionIds.remove(member.id);
      }
    });
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

    final updatedEvent = Event(
      id: _currentEvent!.id,
      title: _currentEvent!.title,
      time: _currentEvent!.time,
      frequency: _currentEvent!.frequency,
      oneTimeDate: _currentEvent!.oneTimeDate,
      repeatingDays: _currentEvent!.repeatingDays,
      memberIds: updatedMemberIds,
      createdAt: _currentEvent!.createdAt,
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
    final c = context.conv;
    final isEventMode = _currentEvent != null || widget.selectionMode;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        surfaceTintColor: c.bg,
        title: Text(
          isEventMode ? 'Manage Event Members' : 'Manage Members',
          style: AppTypography.fraunces(
            fontSize: 22,
            fontWeight: FontWeight.w400,
            color: c.ink,
          ),
        ),
        iconTheme: IconThemeData(color: c.ink2),
        actions: [
          if (widget.selectionMode)
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_selectionIds.toList()),
              child: Text(
                'Done',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.primary,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showRenameInfo,
              tooltip: 'About historical records',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(c, isEventMode),
                const SizedBox(height: 18),
                _buildSearchRow(c, isEventMode),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: RepaintBoundary(
              child: AnimatedSwitcher(
                duration: widget.disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                child: _buildBodyContent(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ConvocationColors c, bool isEventMode) {
    final families = _families ?? [];
    final realFamilies = families.where((f) => !f.isAutoSingleton).toList();
    final memberCount = _getAllMembers(families).length;

    if (isEventMode) {
      final selected = widget.selectionMode
          ? _selectionIds.length
          : (_currentEvent?.memberIds.length ?? 0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$selected / $memberCount',
            style: AppTypography.displayNumber(fontSize: 32, color: c.ink),
          ),
          const SizedBox(height: 2),
          Text(
            'assigned',
            style: AppTypography.displayNumber(fontSize: 22, color: c.ink3),
          ),
        ],
      );
    }
    final familyLabel =
        '${realFamilies.length} ${realFamilies.length == 1 ? "family" : "families"}';
    final peopleLabel = memberCount == 1 ? '1 person' : '$memberCount people';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          peopleLabel,
          style: AppTypography.displayNumber(fontSize: 32, color: c.ink),
        ),
        const SizedBox(height: 2),
        Text(
          familyLabel,
          style: AppTypography.displayNumber(fontSize: 22, color: c.ink3),
        ),
      ],
    );
  }

  Widget _buildSearchRow(ConvocationColors c, bool isEventMode) {
    return Container(
      decoration: BoxDecoration(
        color: c.cardSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      child: Row(
        children: [
          Icon(Icons.search, color: c.ink3, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const ValueKey('member_search_field'),
              controller: _inputController,
              focusNode: _inputFocusNode,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              onSubmitted: _addMember,
              style: AppTypography.geist(fontSize: 14, color: c.ink),
              decoration: InputDecoration(
                hintText:
                    isEventMode ? 'Find or add to event' : 'Find or add member',
                hintStyle: AppTypography.geist(fontSize: 14, color: c.ink3),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: c.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: const ValueKey('member_add_fab'),
              borderRadius: BorderRadius.circular(12),
              onTap: _isAdding
                  ? null
                  : () => _addMember(_inputController.text),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: _isAdding
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: c.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(Icons.add, color: c.onPrimary, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    final c = context.conv;

    if (_isLoading && _families == null) {
      return _buildSkeleton(c);
    }

    if (_error != null && _families == null) {
      return Center(
        key: const ValueKey('error'),
        child: Text('Error: $_error'),
      );
    }

    final families = _families ?? [];
    final isEventMode = _currentEvent != null || widget.selectionMode;
    final searchTerm = _inputController.text.toLowerCase();
    final selectedIds = widget.selectionMode
        ? _selectionIds
        : (_currentEvent?.memberIds.toSet() ?? <String>{});

    List<Member> filter(List<Member> ms) => ms
        .where((m) => m.displayNameLowercase.contains(searchTerm))
        .toList();

    final children = <Widget>[];

    if (isEventMode) {
      final all = filter(_getAllMembers(families));
      all.sort((a, b) {
        final aSel = selectedIds.contains(a.id);
        final bSel = selectedIds.contains(b.id);
        if (aSel && !bSel) return -1;
        if (!aSel && bSel) return 1;
        return a.displayName.compareTo(b.displayName);
      });
      if (all.isNotEmpty) {
        children.add(ConvSectionLabel(label: 'Roster · ${all.length}'));
      }
      for (final m in all) {
        children.add(_MemberRow(
          member: m,
          isEventMode: true,
          isSelected: selectedIds.contains(m.id),
          onToggle: (v) => widget.selectionMode
              ? _toggleSelection(m, v)
              : _toggleEventMember(m, v),
          onEdit: () => _editMember(m),
          onDelete: () => widget.selectionMode
              ? _toggleSelection(m, false)
              : _toggleEventMember(m, false),
        ));
      }
    } else {
      final realFamilies = families.where((f) => !f.isAutoSingleton).toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      for (final f in realFamilies) {
        final filtered = filter(f.members)
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        if (filtered.isEmpty) continue;
        children.add(
          ConvSectionLabel(label: '${f.displayName} · ${filtered.length}'),
        );
        for (final m in filtered) {
          children.add(_MemberRow(
            member: m,
            isEventMode: false,
            isSelected: false,
            onToggle: (_) {},
            onEdit: () => _editMember(m),
            onDelete: () => _deleteMember(m),
          ));
        }
      }
      final loners = <Member>[
        for (final f in families)
          if (f.isAutoSingleton) ...f.members,
      ];
      final filteredLoners = filter(loners)
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      if (filteredLoners.isNotEmpty) {
        children.add(
          ConvSectionLabel(label: 'Loners · ${filteredLoners.length}'),
        );
        for (final m in filteredLoners) {
          children.add(_MemberRow(
            member: m,
            isEventMode: false,
            isSelected: false,
            onToggle: (_) {},
            onEdit: () => _editMember(m),
            onDelete: () => _deleteMember(m),
          ));
        }
      }
    }

    return ListView(
      key: const ValueKey('data'),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 80),
      children: children,
    );
  }

  Widget _buildSkeleton(ConvocationColors c) {
    return ListView(
      key: const ValueKey('loading'),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 80),
      children: [
        AppShimmer(
          width: 100,
          height: 12,
          borderRadius: BorderRadius.circular(6),
          disableAnimations: widget.disableAnimations,
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < 8; i++) ...[
          Row(
            children: [
              AppShimmer(
                width: 40,
                height: 40,
                borderRadius: BorderRadius.circular(20),
                disableAnimations: widget.disableAnimations,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppShimmer(
                      width: 140,
                      height: 14,
                      borderRadius: BorderRadius.circular(7),
                      disableAnimations: widget.disableAnimations,
                    ),
                    const SizedBox(height: 6),
                    AppShimmer(
                      width: 80,
                      height: 10,
                      borderRadius: BorderRadius.circular(5),
                      disableAnimations: widget.disableAnimations,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isEventMode,
    required this.isSelected,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Member member;
  final bool isEventMode;
  final bool isSelected;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.conv;
    final letter = member.displayName.isEmpty
        ? '?'
        : member.displayName.characters.first.toUpperCase();

    return Dismissible(
      key: ValueKey('dismiss_${member.id}_$isEventMode'),
      direction: DismissDirection.endToStart,
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: c.absent,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEventMode ? 'Remove from event' : 'Delete Member',
              style: AppTypography.geist(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.delete_outline, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isEventMode ? () => onToggle(!isSelected) : onEdit,
          onLongPress: onEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                ConvAvatar(
                  letter: letter,
                  size: 40,
                  tone: isEventMode && isSelected
                      ? ConvTone.present
                      : ConvTone.neutral,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.geist(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEventMode
                            ? (isSelected ? 'Assigned' : 'Not assigned')
                            : 'Member',
                        style: AppTypography.geist(
                          fontSize: 12,
                          color: c.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isEventMode)
                  ConvToggle(value: isSelected, onChanged: onToggle)
                else
                  ConvIconButton(
                    icon: Icons.edit_outlined,
                    size: 32,
                    iconSize: 18,
                    color: c.ink3,
                    onPressed: onEdit,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
