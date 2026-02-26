import 'dart:math';

import 'package:flutter/material.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/attendance_status.dart';
import '../../attendance/models/family.dart';
import '../../attendance/models/member.dart';

class FamilyDetailsPage extends StatefulWidget {
  const FamilyDetailsPage({
    super.key,
    required this.family,
    required this.repository,
  });

  final Family family;
  final AttendanceRepository repository;

  @override
  State<FamilyDetailsPage> createState() => _FamilyDetailsPageState();
}

class _FamilyDetailsPageState extends State<FamilyDetailsPage> {
  late Family _family;

  @override
  void initState() {
    super.initState();
    _family = widget.family;
  }

  Future<void> _addMember() async {
    final name = await _promptName('Add Member', 'Member Name');
    if (name == null) return;

    final member = Member(
      id: 'member-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1000)}',
      displayName: name,
      isVisitor: false,
      defaultStatus: AttendanceStatus.absent,
    );

    try {
      final updatedFamily = await widget.repository.addMember(
        _family.id,
        member,
      );
      setState(() {
        _family = updatedFamily;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding member: $e')));
      }
    }
  }

  Future<String?> _promptName(String title, String label) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'Enter name',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    ).then((result) => (result == null || result.isEmpty) ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_family.displayName)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Members',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_family.members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('No members yet.'),
            ),
          ..._family.members.map((member) {
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                child: Text(member.displayName.characters.first.toUpperCase()),
              ),
              title: Text(member.displayName),
              subtitle: member.isVisitor ? const Text('Visitor') : null,
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMember,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
      ),
    );
  }
}
