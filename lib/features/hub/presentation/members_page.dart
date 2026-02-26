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
  late Future<List<Family>> _familiesFuture;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quickAddController =
      TextEditingController(); // For "Quick Add Member"

  @override
  void initState() {
    super.initState();
    _loadFamilies();
  }

  void _loadFamilies() {
    setState(() {
      // Optimized delay for better responsiveness while still allowing transition to finish
      _familiesFuture = Future.delayed(
        const Duration(milliseconds: 400),
        () => widget.attendanceRepository.fetchFamilies(),
      );
    });
  }

  List<Member> _getAllMembers(List<Family> families) {
    // Flatten families to get all members
    // In a real app we might care about family structure, but the design shows a flat list
    return families.expand((f) => f.members).toList();
  }

  Future<void> _addMember(String name) async {
    if (name.trim().isEmpty) return;

    // Logic to add a member.
    // Since we only have a name, we need to decide which family to add them to.
    // Or create a new family for them?
    // The "Quick Add Member" implies adding a single person.
    // For simplicity, let's create a new 'Individual' family for them or add to a default group.
    // Or better, creating a new Family with just this member.
    try {
      await widget.attendanceRepository.addFamily(
        name,
      ); // Assuming addFamily creates a family with the name.
      // Wait, fetchFamilies returns families. addFamily takes displayName.
      // But we want to add a Member.
      // If we add a family, it has no members initially? Let's check repository.
      // Repository: addFamily(displayName) -> returns Family(members: []).
      // Then we need to add a member to it?
      // Or maybe we treat "Family" as the entity itself if it's a single person?
      // The data model separates Family and Member.
      // Let's create a family with that name, then add a member with that name to it.

      final newFamily = await widget.attendanceRepository.addFamily(name);
      final newMember = Member(id: const Uuid().v4(), displayName: name);
      await widget.attendanceRepository.addMember(newFamily.id, newMember);

      _quickAddController.clear();
      _loadFamilies();
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
    // Repository doesn't seem to have removeMember?
    // Checking AttendanceRepository... checking file content...
    // It has fetchFamilies, saveFamilies, addMember, addFamily. No delete.
    // We'll have to implement delete manually by fetching, modifying, and saving.

    try {
      final families = await widget.attendanceRepository.fetchFamilies();
      final updatedFamilies = families
          .map((f) {
            // Remove member from family
            final updatedMembers = f.members
                .where((m) => m.id != member.id)
                .toList();
            return f.copyWith(members: updatedMembers);
          })
          .where((f) => f.members.isNotEmpty)
          .toList(); // Optional: remove empty families? Maybe keep them.

      await widget.attendanceRepository.saveFamilies(updatedFamilies);
      _loadFamilies();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Removed ${member.displayName}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to remove member: $e')));
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
                          border: Border.all(
                            color: colorScheme.outlineVariant,
                          ), // Outline variant?
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: _quickAddController,
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
                      mini:
                          false, // Stitch design uses a 50x50 button, FAB is close
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
            child: FutureBuilder<List<Family>>(
              key: ValueKey(_familiesFuture),
              future: _familiesFuture,
              builder: (context, snapshot) {
                return RepaintBoundary(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildBodyContent(context, snapshot),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(
    BuildContext context,
    AsyncSnapshot<List<Family>> snapshot,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (snapshot.connectionState == ConnectionState.waiting) {
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

    if (snapshot.hasError) {
      return Center(
        key: const ValueKey('error'),
        child: Text('Error: ${snapshot.error}'),
      );
    }

    final families = snapshot.data ?? [];
    final allMembers = _getAllMembers(families);
    final searchTerm = _searchController.text.toLowerCase();
    final filteredMembers = allMembers.where((m) {
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
                (ctx, i) => Divider(
                  color: colorScheme.outlineVariant,
                  height: 1,
                ),
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
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
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
