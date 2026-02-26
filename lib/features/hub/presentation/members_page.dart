import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; // Ensure uuid package is available
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key, required this.attendanceRepository});

  final AttendanceRepository attendanceRepository;

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  List<Family>? _families;
  bool _isLoading = true;
  Object? _error;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quickAddController =
      TextEditingController(); // For "Quick Add Member"

  @override
  void initState() {
    super.initState();
    _loadFamilies(isInitial: true);
  }

  Future<void> _loadFamilies({bool isInitial = false}) async {
    if (isInitial) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      // Optimized delay for better responsiveness while still allowing transition to finish
      await Future.delayed(const Duration(milliseconds: 400));
    }

    try {
      final families = await widget.attendanceRepository.fetchFamilies();
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
    // Flatten families to get all members
    // In a real app we might care about family structure, but the design shows a flat list
    return families.expand((f) => f.members).toList();
  }

  Future<void> _addMember(String name) async {
    if (name.trim().isEmpty) return;

    try {
      final newFamily = await widget.attendanceRepository.addFamily(name);
      final newMember = Member(id: const Uuid().v4(), displayName: name);
      final updatedFamily = await widget.attendanceRepository.addMember(
        newFamily.id,
        newMember,
      );

      if (mounted) {
        setState(() {
          // Add the newly created family with its member to our local list
          _families = [...(_families ?? []), updatedFamily];
        });
      }

      _quickAddController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Added $name')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add member: $e')));
    }
  }

  Future<void> _deleteMember(Member member) async {
    if (_families == null) return;

    final originalFamilies = List<Family>.from(_families!);

    try {
      final updatedFamilies = _families!
          .map((f) {
            // Remove member from family
            final updatedMembers =
                f.members.where((m) => m.id != member.id).toList();
            return f.copyWith(members: updatedMembers);
          })
          .where((f) => f.members.isNotEmpty)
          .toList();

      setState(() {
        _families = updatedFamilies;
      });

      await widget.attendanceRepository.saveFamilies(updatedFamilies);

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surface,
        title: Text(
          'Manage Members',
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
          // Search & Quick Add Section
          Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'Find members',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
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
                const SizedBox(height: 16),

                // Quick Add Label
                Text(
                  'QUICK ADD MEMBER',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          border: Border.all(color: colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: _quickAddController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'Enter full name',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onSubmitted: (val) => _addMember(val),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      heroTag: 'fab',
                      mini: false,
                      elevation: 1,
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      onPressed: () => _addMember(_quickAddController.text),
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: RepaintBoundary(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
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

    if (_isLoading && _families == null) {
      return ListView.separated(
        key: const ValueKey('loading'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 8,
        separatorBuilder:
            (ctx, i) =>
                Divider(color: Colors.grey.withValues(alpha: 0.2), height: 1),
        itemBuilder: (context, index) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Colors.grey.withValues(alpha: 0.1),
            ),
            title: Container(
              width: 150,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            subtitle: Container(
              width: 80,
              height: 12,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
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
    final searchTerm = _searchController.text.toLowerCase();
    final filteredMembers =
        allMembers.where((m) {
          return m.displayName.toLowerCase().contains(searchTerm);
        }).toList();

    return Column(
      key: const ValueKey('data'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Regular Members',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${filteredMembers.length}',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 12,
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
            separatorBuilder:
                (ctx, i) => Divider(color: colorScheme.outlineVariant, height: 1),
            itemBuilder: (context, index) {
              final member = filteredMembers[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    member.displayName.isNotEmpty
                        ? member.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  member.displayName,
                  style: TextStyle(color: colorScheme.onSurface),
                ),
                subtitle: Text(
                  'Member',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => _deleteMember(member),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

