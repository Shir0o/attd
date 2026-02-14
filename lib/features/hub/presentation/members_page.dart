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
      _familiesFuture = widget.attendanceRepository.fetchFamilies();
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
    // Stitch Colors
    const primaryColor = Color(0xFF6750A4);
    const onPrimaryColor = Color(0xFFFFFFFF);
    const surfaceColor = Color(0xFFFEF7FF);
    const onSurfaceColor = Color(0xFF1D1B20);
    const onSurfaceVariantColor = Color(0xFF49454F);
    const surfaceContainerHighColor = Color(0xFFECE6F0);

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        surfaceTintColor: surfaceColor,
        title: const Text(
          'Manage Members',
          style: TextStyle(color: onSurfaceColor),
        ),
        iconTheme: const IconThemeData(color: onSurfaceVariantColor),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: surfaceContainerHighColor, height: 1),
        ),
      ),
      body: Column(
        children: [
          // Search & Quick Add Section
          Container(
            color: surfaceColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search
                Container(
                  decoration: BoxDecoration(
                    color: surfaceContainerHighColor,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'Find members',
                      hintStyle: const TextStyle(color: onSurfaceVariantColor),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: onSurfaceVariantColor,
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
                const Text(
                  'QUICK ADD MEMBER',
                  style: TextStyle(
                    color: primaryColor,
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
                          color: surfaceColor,
                          border: Border.all(
                            color: Colors.grey.shade400,
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
                      mini:
                          false, // Stitch design uses a 50x50 button, FAB is close
                      elevation: 1,
                      backgroundColor: primaryColor,
                      foregroundColor: onPrimaryColor,
                      onPressed: () => _addMember(_quickAddController.text),
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
          ),

          FutureBuilder<List<Family>>(
            future: _familiesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Expanded(
                  child: Center(child: Text('Error: ${snapshot.error}')),
                );
              }

              final families = snapshot.data ?? [];
              final allMembers = _getAllMembers(families);

              // Filter
              final searchTerm = _searchController.text.toLowerCase();
              final filteredMembers = allMembers.where((m) {
                return m.displayName.toLowerCase().contains(searchTerm);
              }).toList();

              return Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Regular Members',
                            style: TextStyle(
                              color: onSurfaceVariantColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFEADDFF,
                              ), // Primary Container
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${filteredMembers.length}',
                              style: const TextStyle(
                                color: Color(0xFF21005D),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ), // On Primary Container
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: filteredMembers.length,
                        separatorBuilder: (ctx, i) => Divider(
                          color: Colors.grey.withValues(alpha: 0.2),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final member = filteredMembers[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              child: Text(
                                member.displayName.isNotEmpty
                                    ? member.displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              member.displayName,
                              style: const TextStyle(color: onSurfaceColor),
                            ),
                            subtitle: const Text(
                              'Member',
                              style: TextStyle(
                                fontSize: 12,
                                color: onSurfaceVariantColor,
                              ),
                            ), // Date joined not available in model
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: onSurfaceVariantColor,
                              ),
                              onPressed: () => _deleteMember(member),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
