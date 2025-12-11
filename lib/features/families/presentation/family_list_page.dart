import 'package:flutter/material.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/family.dart';
import 'add_family_page.dart';
import 'family_details_page.dart';

class FamilyListPage extends StatefulWidget {
  const FamilyListPage({super.key, required this.repository});

  final AttendanceRepository repository;

  @override
  State<FamilyListPage> createState() => _FamilyListPageState();
}

class _FamilyListPageState extends State<FamilyListPage> {
  late Future<List<Family>> _familiesFuture;

  @override
  void initState() {
    super.initState();
    _loadFamilies();
  }

  void _loadFamilies() {
    setState(() {
      _familiesFuture = widget.repository.fetchFamilies();
    });
  }

  Future<void> _addFamily() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddFamilyPage(repository: widget.repository),
      ),
    );

    if (result != null) {
      _loadFamilies();
    }
  }

  void _openFamily(Family family) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FamilyDetailsPage(
          family: family,
          repository: widget.repository,
        ),
      ),
    );
    _loadFamilies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Families'),
      ),
      body: FutureBuilder<List<Family>>(
        future: _familiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final families = snapshot.data ?? [];

          if (families.isEmpty) {
            return const Center(child: Text('No families found. Add one!'));
          }

          return ListView.separated(
            itemCount: families.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final family = families[index];
              final memberCount = family.members.length;
              return ListTile(
                leading: CircleAvatar(
                  child: Text(family.displayName.characters.first.toUpperCase()),
                ),
                title: Text(family.displayName),
                subtitle: Text('$memberCount members'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _openFamily(family),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFamily,
        tooltip: 'Add Family',
        child: const Icon(Icons.add),
      ),
    );
  }
}
